//
//  TellerConnectView.swift
//  Credit Card Benefit Tracker
//
//  The ONLY place account linking happens. Hosts Teller Connect (a JS widget)
//  inside a WKWebView. The user's bank credentials are entered ONLY on the
//  bank's page rendered inside Teller Connect — this app never sees them.
//
//  IMPORTANT: On success, a Teller `accessToken` briefly passes through the app
//  here. It is handed straight to the backend and then discarded. It is NEVER
//  persisted on the device (no Keychain, no UserDefaults, no SwiftData).
//

import SwiftUI
import WebKit

struct TellerConnectView: UIViewRepresentable {
    /// Called on a successful enrollment. The accessToken is transient — pass it
    /// to the backend and drop it; do not store it.
    let onSuccess: (_ accessToken: String, _ enrollmentId: String, _ institution: String) -> Void
    /// Called when the user exits or Teller Connect fails.
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSuccess: onSuccess, onExit: onExit)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "teller")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        // teller.io must be the base URL so connect.js is served the right origin.
        webView.loadHTMLString(Self.connectHTML, baseURL: URL(string: "https://teller.io"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "teller")
    }

    // Inline HTML that loads Teller Connect and immediately opens it.
    private static var connectHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="https://cdn.teller.io/connect/connect.js"></script>
        </head>
        <body>
          <script>
            function post(msg) {
              try { window.webkit.messageHandlers.teller.postMessage(msg); } catch (e) {}
            }
            function start() {
              try {
                var connect = TellerConnect.setup({
                  applicationId: "\(TellerConfig.applicationId)",
                  environment: "\(TellerConfig.environment)",
                  onSuccess: function(enrollment) {
                    post(JSON.stringify(enrollment));
                  },
                  onExit: function() { post("EXIT"); },
                  onFailure: function(err) { post("FAILURE"); }
                });
                connect.open();
              } catch (e) {
                post("FAILURE");
              }
            }
            if (window.TellerConnect) { start(); }
            else { window.addEventListener('load', start); }
          </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onSuccess: (String, String, String) -> Void
        let onExit: () -> Void

        init(onSuccess: @escaping (String, String, String) -> Void, onExit: @escaping () -> Void) {
            self.onSuccess = onSuccess
            self.onExit = onExit
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "teller", let body = message.body as? String else { return }

            if body == "EXIT" || body == "FAILURE" {
                onExit()
                return
            }

            // Parse the Teller Connect enrollment object. Shape (per Teller docs):
            // {
            //   "accessToken": "token_...",
            //   "user": { "id": "usr_..." },
            //   "enrollment": {
            //     "id": "enr_...",
            //     "institution": { "name": "Bank Name" }
            //   }
            // }
            guard let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                onExit()
                return
            }

            let accessToken = json["accessToken"] as? String ?? ""
            let enrollment = json["enrollment"] as? [String: Any]
            let enrollmentId = enrollment?["id"] as? String ?? ""
            let institution = (enrollment?["institution"] as? [String: Any])?["name"] as? String ?? ""

            guard !accessToken.isEmpty else {
                onExit()
                return
            }

            onSuccess(accessToken, enrollmentId, institution)
        }
    }
}

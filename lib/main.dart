import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

Future main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  setup();

  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: new MyApp()));
}

void setup() async {
  await Future.delayed(const Duration(milliseconds: 100));
  FlutterNativeSplash.remove();
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        clearCache: true,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.blue,
      ),
      onRefresh: () async {
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: Column(children: <Widget>[
      Visibility(
        visible: false,
        child: TextField(
          decoration: InputDecoration(prefixIcon: Icon(Icons.search)),
          controller: urlController,
          keyboardType: TextInputType.url,
          onSubmitted: (value) {
            var url = Uri.parse(value);
            if (url.scheme.isEmpty) {
              url = Uri.parse("https://www.google.com/search?q=" + value);
            }
            webViewController?.loadUrl(urlRequest: URLRequest(url: url));
          },
        ),
      ),
      Expanded(
        child: Stack(
          children: [
            InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(
                  url: Uri.parse(
                      "https://walmartglobal.service-now.com/sn_va_web_client_login.do?sysparm_redirect_uri=https://walmartglobal.service-now.com/sn_va_web_client_app_embed.do")),
              initialOptions: options,
              pullToRefreshController: pullToRefreshController,
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onLoadStart: (controller, url) {
                setState(() {
                  this.url = url.toString();
                  urlController.text = this.url;
                });
              },
              androidOnPermissionRequest: (controller, origin, resources) async {
                return PermissionRequestResponse(
                    resources: resources, action: PermissionRequestResponseAction.GRANT);
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                var uri = navigationAction.request.url!;

                if (!["http", "https", "file", "chrome", "data", "javascript", "about"]
                    .contains(uri.scheme)) {
                  if (await canLaunch(url)) {
                    // Launch the App
                    await launch(
                      url,
                    );
                    // and cancel the request
                    return NavigationActionPolicy.CANCEL;
                  }
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStop: (controller, url) async {
                pullToRefreshController.endRefreshing();
                setState(() {
                  if (url == "https://walmartglobal.service-now.com/wm_sp") {
                    webViewController?.loadUrl(
                        urlRequest: URLRequest(
                            url: Uri.parse(
                                "https://walmartglobal.service-now.com/sn_va_web_client_app_embed.do")));
                  } else {
                    this.url = url.toString();
                    urlController.text = this.url;
                  }
                });
              },
              onLoadError: (controller, url, code, message) {
                pullToRefreshController.endRefreshing();
              },
              onProgressChanged: (controller, progress) {
                if (progress == 100) {
                  pullToRefreshController.endRefreshing();
                }
                setState(() {
                  this.progress = progress / 100;
                  urlController.text = this.url;
                });
              },
              onUpdateVisitedHistory: (controller, url, androidIsReload) {
                setState(() {
                  this.url = url.toString();
                  urlController.text = this.url;
                });
              },
              onConsoleMessage: (controller, consoleMessage) {
                print(consoleMessage);
              },
            ),
            progress < 1.0 ? LinearProgressIndicator(value: progress) : Container(),
          ],
        ),
      ),
      Visibility(
        visible: false,
        child: ButtonBar(
          alignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Icon(Icons.arrow_back),
              onPressed: () {
                webViewController?.goBack();
              },
            ),
            ElevatedButton(
              child: Icon(Icons.arrow_forward),
              onPressed: () {
                webViewController?.goForward();
              },
            ),
            ElevatedButton(
              child: Icon(Icons.refresh),
              onPressed: () {
                webViewController?.reload();
              },
            ),
          ],
        ),
      ),
    ])));
  }
}

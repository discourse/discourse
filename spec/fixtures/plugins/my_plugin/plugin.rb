# name: plugin-name
# about: about: my plugin
# version: 0.1
# authors: Frank Zappa

auth_provider title: 'with Ubuntu',
              authenticator: Auth::OpenIdAuthenticator.new('ubuntu', 'https://login.ubuntu.com', trusted: true),
              message: 'Authenticating with Ubuntu (make sure pop up blockers are not enbaled)',
              frame_width: 1000,   # the frame size used for the pop up window, overrides default
              frame_height: 800

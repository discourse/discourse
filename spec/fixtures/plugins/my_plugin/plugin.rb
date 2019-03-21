# name: plugin-name
# about: about: my plugin
# version: 0.1
# authors: Frank Zappa

# the frame size used for the pop up window, overrides default
frame_width = 1000
frame_height = 800

auth_provider title: 'with Ubuntu',
              authenticator:
                Auth::OpenIdAuthenticator.new(
                  'ubuntu',
                  'https://login.ubuntu.com',
                  'ubuntu_login_enabled',
                  trusted: true
                ),
              message:
                'Authenticating with Ubuntu (make sure pop up blockers are not enbaled)',
              frame_width: frame_width,
              frame_height: frame_height

register_javascript <<JS
  console.log("Hello world")
JS

# name: discourse-ssocookie
# about: ubuntu login support for Discourse
# version: 0.1
# authors: Attila-Mihály Balázs

require 'auth/ssocookie_authenticator'

auth_provider :title => 'with Udacity',
              :authenticator => Auth::SsoCookieAuthenticator.new,
              :message => 'Authenticating with Udacity (make sure pop up blockers are not enabled)',
              :frame_width => 1000,
              :frame_height => 800

register_css <<CSS

.btn-social.ssocookie {
  background: #354b59;
}

.btn-social.ssocookie:before {
  content: url("/assets/favicons/udacity.png");
}

CSS

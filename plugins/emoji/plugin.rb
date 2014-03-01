# name: emoji
# about: emoji support for Discourse
# version: 0.1
# authors: Sam Saffron, Robin Ward

register_asset('javascripts/emoji.js.erb', :server_side)
register_asset('stylesheets/emoji.css')

after_initialize do

  # whitelist emojis so that new user can post emojis
  Post::white_listed_image_classes << "emoji"

end

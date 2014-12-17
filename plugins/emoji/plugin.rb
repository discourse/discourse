# name: emoji
# about: emoji support for Discourse
# version: 0.2
# authors: Sam Saffron, Robin Ward, Régis Hanol

load File.expand_path('../lib/emoji/engine.rb', __FILE__)

register_asset('javascripts/emoji.js.erb', :server_side)
register_asset('javascripts/emoji-autocomplete.js', :composer)
register_asset('javascripts/discourse/templates/emoji-toolbar.raw.hbs', :composer)
register_asset('javascripts/emoji-toolbar.js', :composer)
register_asset('stylesheets/emoji.css')

def site_setting_saved(site_setting)
  return unless site_setting.name.to_s == "emoji_set"
  return unless site_setting.value_changed?
  before = "/plugins/emoji/images/#{site_setting.value_was}/"
  after = "/plugins/emoji/images/#{site_setting.value}/"
  Scheduler::Defer.later "Fix Emoji Links" do
    Post.exec_sql("UPDATE posts SET cooked = REPLACE(cooked, :before, :after) WHERE cooked LIKE :like",
      before: before,
      after: after,
      like: "%#{before}%"
    )
  end
end

listen_for(:site_setting_saved)

after_initialize do
  # whitelist emojis so that new user can post emojis
  Post::white_listed_image_classes << "emoji"
end

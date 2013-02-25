require 'discourse_plugin'

module DiscourseEmoji

  class Plugin < DiscoursePlugin

    def setup
      # Add our Assets
      register_js('discourse_emoji',
                    server_side: File.expand_path('../../../vendor/assets/javascripts/discourse_emoji.js', __FILE__))
      register_css('discourse_emoji')
    end

  end
end

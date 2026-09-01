# frozen_string_literal: true

require_relative "../mixins/twitch_onebox"

class Onebox::Engine::TwitchClipsOnebox
  # TwitchOnebox's inclusion hook calls twitch_regexp.
  # rubocop:disable Layout/ClassStructure
  class << self
    def twitch_regexp
      %r{^https?://(?:clips\.twitch\.tv/embed\?clip=|www\.twitch\.tv/[a-zA-Z0-9_]+/clip/|clips\.twitch\.tv/)([a-zA-Z0-9_\-]+)}
    end
  end

  include Onebox::Mixins::TwitchOnebox
  # rubocop:enable Layout/ClassStructure

  requires_iframe_origins "https://clips.twitch.tv"

  def query_params
    "clip=#{twitch_id}"
  end

  def base_url
    "clips.twitch.tv/embed?"
  end
end

# frozen_string_literal: true

require_relative "../mixins/twitch_onebox"

class Onebox::Engine::TwitchVideoOnebox
  include Onebox::Mixins::TwitchOnebox
  class << self
    def twitch_regexp
      %r{^https?://(?:www\.)?twitch\.tv/videos/([0-9]+)}
    end
  end

  def query_params
    "video=v#{twitch_id}"
  end
end

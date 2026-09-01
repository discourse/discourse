# frozen_string_literal: true

require_relative "../mixins/twitch_onebox"

class Onebox::Engine::TwitchStreamOnebox
  include Onebox::Mixins::TwitchOnebox
  class << self
    def twitch_regexp
      /^https?:\/\/(?:www\.|go\.)?twitch\.tv\/(?!directory)([a-zA-Z0-9_]{4,25})$/
    end
  end

  def query_params
    "channel=#{twitch_id}"
  end
end

# frozen_string_literal: true

require_relative '../mixins/twitch_onebox'

class Onebox::Engine::TwitchStreamOnebox
  def self.twitch_regexp
    /^https?:\/\/(?:www\.|go\.)?twitch\.tv\/(?!directory)([a-zA-Z0-9_]{4,25})$/
  end

  include Onebox::Mixins::TwitchOnebox

  def query_params
    "channel=#{twitch_id}"
  end
end

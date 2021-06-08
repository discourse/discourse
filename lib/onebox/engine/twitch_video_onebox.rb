# frozen_string_literal: true

require_relative '../mixins/twitch_onebox'

class Onebox::Engine::TwitchVideoOnebox
  def self.twitch_regexp
    /^https?:\/\/(?:www\.)?twitch\.tv\/videos\/([0-9]+)/
  end

  include Onebox::Mixins::TwitchOnebox

  def query_params
    "video=v#{twitch_id}"
  end
end

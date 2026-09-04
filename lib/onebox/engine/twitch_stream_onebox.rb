# frozen_string_literal: true

require_relative "../mixins/twitch_onebox"

class Onebox::Engine::TwitchStreamOnebox
  # TwitchOnebox's inclusion hook calls twitch_regexp.
  # rubocop:disable Layout/ClassStructure
  class << self
    def twitch_regexp
      /^https?:\/\/(?:www\.|go\.)?twitch\.tv\/(?!directory)([a-zA-Z0-9_]{4,25})$/
    end
  end

  include Onebox::Mixins::TwitchOnebox
  # rubocop:enable Layout/ClassStructure

  def query_params
    "channel=#{twitch_id}"
  end
end

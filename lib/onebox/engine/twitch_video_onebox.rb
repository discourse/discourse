# frozen_string_literal: true

require_relative "../mixins/twitch_onebox"

class Onebox::Engine::TwitchVideoOnebox
  # TwitchOnebox's inclusion hook calls twitch_regexp.
  # rubocop:disable Layout/ClassStructure
  class << self
    def twitch_regexp
      %r{^https?://(?:www\.)?twitch\.tv/videos/([0-9]+)}
    end
  end

  include Onebox::Mixins::TwitchOnebox
  # rubocop:enable Layout/ClassStructure

  def query_params
    "video=v#{twitch_id}"
  end
end

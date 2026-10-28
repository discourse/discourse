# frozen_string_literal: true

module MarkdownEndpoint
  class Timestamp
    def initialize(user)
      @timezone = Time.find_zone(user&.user_option&.timezone) || Time.zone
    end

    def render(time, url:)
      local = time.in_time_zone(@timezone)
      label = text(local).gsub(/[\\`*_\[\]<>]/) { |character| "\\#{character}" }
      %([#{label}](#{url} "#{local.iso8601}"))
    end

    def text(time)
      local = time.in_time_zone(@timezone)
      "#{I18n.l(local, format: :long)} #{local.strftime("%Z")}".squish
    end
  end
end

# frozen_string_literal: true

require "enum_site_setting"

module Chat
  class HomepageChannelSiteSetting < ::EnumSiteSetting
    def self.valid_value?(val)
      val.blank? || values.any? { |v| v[:value].to_s == val.to_s }
    end

    def self.values
      Chat::Channel
        .public_channels
        .where.not(status: :archived)
        .order(:id)
        .map { |channel| { name: channel.title, value: channel.id } }
    end

    def self.translate_names?
      false
    end
  end
end

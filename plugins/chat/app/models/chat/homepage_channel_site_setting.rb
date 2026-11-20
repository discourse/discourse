# frozen_string_literal: true

require "enum_site_setting"

module Chat
  class HomepageChannelSiteSetting < ::EnumSiteSetting
    def self.valid_value?(val)
      val.blank? || selectable_channels.exists?(id: val)
    end

    def self.values
      selectable_channels
        .includes(:chatable)
        .order(:id)
        .map { |channel| { name: channel.title, value: channel.id } }
    end

    def self.translate_names?
      false
    end

    def self.selectable_channels
      Chat::Channel.public_channels.where.not(status: :archived)
    end

    private_class_method :selectable_channels
  end
end

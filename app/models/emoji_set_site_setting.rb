# frozen_string_literal: true

require "enum_site_setting"

class EmojiSetSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    values.any? { |v| v[:value] == val.to_s }
  end

  def self.values
    @values ||= [
      { name: "emoji_set.apple_international", value: "apple" },
      { name: "emoji_set.facebook_messenger", value: "facebook_messenger" },
      { name: "emoji_set.fluentui", value: "fluentui" },
      { name: "emoji_set.google", value: "google" },
      { name: "emoji_set.google_classic", value: "google_classic" },
      { name: "emoji_set.noto", value: "noto" },
      { name: "emoji_set.openmoji", value: "openmoji" },
      { name: "emoji_set.twemoji", value: "twemoji" },
      { name: "emoji_set.twitter", value: "twitter" },
      { name: "emoji_set.standard", value: "unicode" },
      { name: "emoji_set.win10", value: "win10" },
    ]
  end

  def self.translate_names?
    true
  end
end

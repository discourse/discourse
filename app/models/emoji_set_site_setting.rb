# frozen_string_literal: true

require 'enum_site_setting'

class EmojiSetSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val.to_s }
  end

  def self.values
    @values ||= [
      { name: 'emoji_set.apple_international', value: 'apple' },
      { name: 'emoji_set.google', value: 'google' },
      { name: 'emoji_set.twitter', value: 'twitter' },
      { name: 'emoji_set.emoji_one', value: 'emoji_one' },
      { name: 'emoji_set.win10', value: 'win10' },
      { name: 'emoji_set.google_classic', value: 'google_classic' },
      { name: 'emoji_set.facebook_messenger', value: 'facebook_messenger' },
    ]
  end

  def self.translate_names?
    true
  end

end

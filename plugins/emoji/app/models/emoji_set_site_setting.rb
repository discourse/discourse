require 'enum_site_setting'

class EmojiSetSiteSetting < EnumSiteSetting

  def self.valid_value?(val)
    values.any? { |v| v[:value] == val.to_s }
  end

  def self.values
    @values ||= [
      { name: 'apple_international', value: 'apple' },
      { name: 'google', value: 'google' },
      { name: 'twitter', value: 'twitter' },
      { name: 'emoji_one', value: 'emoji_one' },
    ]
  end

  def self.translate_names?
    true
  end

end

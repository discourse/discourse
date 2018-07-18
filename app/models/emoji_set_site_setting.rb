require 'enum_site_setting'

class EmojiSetSiteSetting < EnumSiteSetting

  # fix the URLs when changing the site setting
  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if site_setting.name.to_s == "emoji_set" && site_setting.value_changed?
      Emoji.clear_cache

      previous_value = site_setting.attribute_in_database(:value) || SiteSetting.defaults[:emoji_set]
      before = "/images/emoji/#{previous_value}/"
      after = "/images/emoji/#{site_setting.value}/"

      Scheduler::Defer.later("Fix Emoji Links") do
        DB.exec("UPDATE posts SET cooked = REPLACE(cooked, :before, :after) WHERE cooked LIKE :like",
          before: before,
          after: after,
          like: "%#{before}%"
        )
      end
    end
  end

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

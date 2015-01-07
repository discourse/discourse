require 'enum_site_setting'

class EmojiSetSiteSetting < EnumSiteSetting

  NAME = :emoji_set

  # fix the URLs when changing the site setting
  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if site_setting.name == NAME && site_setting.value_changed?
      Emoji.clear_cache

      previous_value = site_setting.value_was || SiteSetting.defaults[NAME]
      before = "/images/emoji/#{previous_value}/"
      after = "/images/emoji/#{site_setting.value}/"

      Scheduler::Defer.later("Fix Emoji Links") do
        Post.exec_sql("UPDATE posts SET cooked = REPLACE(cooked, :before, :after) WHERE cooked LIKE :like",
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

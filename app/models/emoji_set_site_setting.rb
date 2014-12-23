require 'enum_site_setting'

class EmojiSetSiteSetting < EnumSiteSetting

  # fix the URLs when changing the site setting
  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if site_setting.name.to_s == "emoji_set" && site_setting.value_changed?
      before = "/images/emoji/#{site_setting.value_was}/"
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

# frozen_string_literal: true

# An array of group_ids stored in the format "1|2|3"
# associated with a site setting. This allows us to restrict
# a non-group-list site setting with a list of groups,
# which is necessary for example for "Upcoming changes" settings.
class SiteSettingGroup < ActiveRecord::Base
  belongs_to :site_setting

  validates :name, presence: true, uniqueness: true

  def self.setting_group_ids
    return {} unless can_access_db?

    DB
      .query("SELECT name, group_ids FROM site_setting_groups")
      .each_with_object({}) do |row, hash|
        hash[row.name.to_sym] = row.group_ids.split("|").map(&:to_i)
      end
  end

  def self.generate_setting_group_map
    return {} unless can_access_db?

    Hash[*SiteSettingGroup.setting_group_ids.flatten]
  end

  def self.can_access_db?
    !GlobalSetting.skip_redis? && !GlobalSetting.skip_db? &&
      ActiveRecord::Base.connection.table_exists?(self.table_name)
  end
end

# == Schema Information
#
# Table name: site_setting_groups
#
#  id         :bigint           not null, primary key
#  group_ids  :string           not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_site_setting_groups_on_name  (name) UNIQUE
#

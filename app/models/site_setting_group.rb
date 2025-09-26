# frozen_string_literal: true

# An array of group_ids stored in the format "1|2|3"
# associated with a site setting. This allows us to restrict
# a non-group-list site setting with a list of groups,
# which is necessary for example for "Upcoming changes" settings.
class SiteSettingGroup < ActiveRecord::Base
  belongs_to :site_setting

  validates :name, presence: true, uniqueness: true
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

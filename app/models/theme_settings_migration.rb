# frozen_string_literal: true

class ThemeSettingsMigration < ActiveRecord::Base
  belongs_to :theme
  belongs_to :theme_field

  validates :theme_id, presence: true, uniqueness: { scope: :version }
  validates :theme_field_id, presence: true

  validates :version, presence: true
  validates :name, presence: true
  validates :diff, presence: true

  def calculate_diff(settings_before, settings_after)
    diff = { additions: [], deletions: [] }

    before_keys = settings_before.keys
    after_keys = settings_after.keys

    removed_keys = before_keys - after_keys
    removed_keys.each { |key| diff[:deletions] << { key: key, val: settings_before[key] } }

    added_keys = after_keys - before_keys
    added_keys.each { |key| diff[:additions] << { key: key, val: settings_after[key] } }

    common_keys = before_keys & after_keys
    common_keys.each do |key|
      if settings_before[key] != settings_after[key]
        diff[:deletions] << { key: key, val: settings_before[key] }
        diff[:additions] << { key: key, val: settings_after[key] }
      end
    end

    self.diff = diff
  end
end

# == Schema Information
#
# Table name: theme_settings_migrations
#
#  id             :bigint           not null, primary key
#  theme_id       :integer          not null
#  theme_field_id :integer          not null
#  version        :integer          not null
#  name           :string(150)      not null
#  diff           :json             not null
#  created_at     :datetime         not null
#
# Indexes
#
#  index_theme_settings_migrations_on_theme_field_id        (theme_field_id) UNIQUE
#  index_theme_settings_migrations_on_theme_id_and_version  (theme_id,version) UNIQUE
#

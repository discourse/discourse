# frozen_string_literal: true

class ThemeTranslationOverride < ActiveRecord::Base
  belongs_to :theme

  after_commit do
    theme.clear_cached_settings!
    theme.remove_from_cache!
    theme.theme_fields.where(target_id: Theme.targets[:translations]).update_all(value_baked: nil)
  end
end

# == Schema Information
#
# Table name: theme_translation_overrides
#
#  id              :bigint           not null, primary key
#  theme_id        :integer          not null
#  locale          :string           not null
#  translation_key :string           not null
#  value           :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_theme_translation_overrides_on_theme_id  (theme_id)
#  theme_translation_overrides_unique             (theme_id,locale,translation_key) UNIQUE
#

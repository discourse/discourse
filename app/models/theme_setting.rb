# frozen_string_literal: true

class ThemeSetting < ActiveRecord::Base
  belongs_to :theme

  has_many :upload_references, as: :target, dependent: :destroy

  TYPES_ENUM =
    Enum.new(integer: 0, float: 1, string: 2, bool: 3, list: 4, enum: 5, upload: 6, objects: 7)

  MAXIMUM_JSON_VALUE_SIZE_BYTES = 0.5 * 1024 * 1024 # 0.5 MB

  validates_presence_of :name, :theme
  validates :data_type, inclusion: { in: TYPES_ENUM.values }
  validate :json_value_size, if: -> { self.data_type == TYPES_ENUM[:objects] }
  validates :name, length: { maximum: 255 }

  after_save :clear_settings_cache
  after_destroy :clear_settings_cache

  after_save do
    if self.data_type == ThemeSetting.types[:upload] && saved_change_to_value?
      UploadReference.ensure_exist!(upload_ids: [self.value], target: self)
    end

    if theme.theme_modifier_set.refresh_theme_setting_modifiers(
         target_setting_name: self.name,
         target_setting_value: self.value,
       )
      theme.theme_modifier_set.save!
    end
  end

  def clear_settings_cache
    # All necessary caches will be cleared on next ensure_baked!
    theme.settings_field&.invalidate_baked!
  end

  def self.types
    TYPES_ENUM
  end

  def self.guess_type(value)
    case value
    when Integer
      types[:integer]
    when Float
      types[:float]
    when String
      types[:string]
    when TrueClass, FalseClass
      types[:bool]
    end
  end

  private

  def json_value_size
    if json_value.to_json.size > MAXIMUM_JSON_VALUE_SIZE_BYTES
      errors.add(
        :json_value,
        I18n.t(
          "theme_settings.errors.json_value.too_large",
          max_size: MAXIMUM_JSON_VALUE_SIZE_BYTES / 1024 / 1024,
        ),
      )
    end
  end
end

# == Schema Information
#
# Table name: theme_settings
#
#  id         :bigint           not null, primary key
#  name       :string(255)      not null
#  data_type  :integer          not null
#  value      :text
#  theme_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  json_value :jsonb
#

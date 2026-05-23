# frozen_string_literal: true

class ThemeSetting < ActiveRecord::Base
  belongs_to :theme

  has_many :upload_references, as: :target, dependent: :destroy

  TYPES_ENUM =
    Enum.new(integer: 0, float: 1, string: 2, bool: 3, list: 4, enum: 5, upload: 6, objects: 7)

  MAXIMUM_JSON_VALUE_SIZE_BYTES = 0.5 * 1024 * 1024 # 0.5 MB

  validates :name, :theme, presence: true
  validates :data_type, inclusion: { in: TYPES_ENUM.values }
  validate :json_value_size, if: -> { data_type == TYPES_ENUM[:objects] }
  validates :name, length: { maximum: 255 }

  after_destroy :clear_settings_cache
  after_save :clear_settings_cache

  after_save do
    if data_type == ThemeSetting.types[:upload] && saved_change_to_value?
      UploadReference.ensure_exist!(upload_ids: [value], target: self)
    elsif data_type == ThemeSetting.types[:objects] && saved_change_to_json_value? &&
          json_value.present?
      upload_ids =
        SchemaSettingsObjectValidator.upload_ids(
          schema: theme.settings[name.to_sym].schema,
          objects: json_value,
        )

      UploadReference.ensure_exist!(upload_ids: upload_ids, target: self)
    end

    if theme.theme_modifier_set.refresh_theme_setting_modifiers(
         target_setting_name: name,
         target_setting_value: value,
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
#  data_type  :integer          not null
#  json_value :jsonb
#  name       :string(255)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  theme_id   :integer          not null
#

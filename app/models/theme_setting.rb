# frozen_string_literal: true

class ThemeSetting < ActiveRecord::Base
  belongs_to :theme

  has_many :upload_references, as: :target, dependent: :destroy

  TYPES_ENUM =
    Enum.new(integer: 0, float: 1, string: 2, bool: 3, list: 4, enum: 5, upload: 6, objects: 7)

  validates_presence_of :name, :theme
  before_validation :objects_type_enabled
  validates :data_type, inclusion: { in: TYPES_ENUM.values }
  validates :name, length: { maximum: 255 }

  after_save :clear_settings_cache
  after_destroy :clear_settings_cache

  after_save do
    if self.data_type == ThemeSetting.types[:upload] && saved_change_to_value?
      UploadReference.ensure_exist!(upload_ids: [self.value], target: self)
    end
  end

  def clear_settings_cache
    # All necessary caches will be cleared on next ensure_baked!
    theme.settings_field&.invalidate_baked!
  end

  def self.types
    TYPES_ENUM
  end

  def self.acceptable_value_for_type?(value, type)
    case type
    when self.types[:integer]
      value.is_a?(Integer)
    when self.types[:float]
      value.is_a?(Integer) || value.is_a?(Float)
    when self.types[:bool]
      value.is_a?(TrueClass) || value.is_a?(FalseClass)
    when self.types[:list]
      value.is_a?(String)
    when self.types[:objects]
      # TODO: This is a simple check now but we want to validate the default objects agianst the schema as well.
      value.is_a?(Array)
    else
      true
    end
  end

  def self.value_in_range?(value, range, type)
    if type == self.types[:integer] || type == self.types[:float]
      range.include? value
    elsif type == self.types[:string]
      range.include? value.to_s.length
    end
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

  def objects_type_enabled
    if self.data_type == ThemeSetting.types[:objects] &&
         !SiteSetting.experimental_objects_type_for_theme_settings
      self.data_type = nil
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

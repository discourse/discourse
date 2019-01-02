class ThemeSetting < ActiveRecord::Base
  belongs_to :theme

  validates_presence_of :name, :theme
  validates :data_type, numericality: { only_integer: true }
  validates :name, length: { maximum: 255 }

  after_save do
    theme.clear_cached_settings!
    theme.remove_from_cache!
    theme.theme_fields.update_all(value_baked: nil)
    theme.theme_settings.reload
    SvgSprite.expire_cache if self.name.to_s.include?("_icon")
    CSP::Extension.clear_theme_extensions_cache! if name.to_s == CSP::Extension::THEME_SETTING
  end

  def self.types
    @types ||= Enum.new(integer: 0, float: 1, string: 2, bool: 3, list: 4, enum: 5)
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
end

# == Schema Information
#
# Table name: theme_settings
#
#  id         :bigint(8)        not null, primary key
#  name       :string(255)      not null
#  data_type  :integer          not null
#  value      :text
#  theme_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

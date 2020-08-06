# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting
  FONTS = {
    "Helvetica" => "Helvetica, Arial, sans-serif",
    "Open Sans" => "Open Sans, Helvetica, Arial, sans-serif",
    "Oxanium" => "Oxanium, Helvetica, Arial, sans-serif",
    "Roboto" => "Roboto, Helvetica, Arial, sans-serif",
    "Lato" => "Lato, Helvetica, Arial, sans-serif",
    "NotoSansJP" => "NotoSansJP, Helvetica, Arial, sans-serif",
    "Montserrat" => "Montserrat, Helvetica, Arial, sans-serif",
    "RobotoCondensed" => "RobotoCondensed, Helvetica, Arial, sans-serif",
    "SourceSansPro" => "SourceSansPro, Helvetica, Arial, sans-serif",
    "Oswald" => "Oswald, Helvetica, Arial, sans-serif",
    "Raleway" => "Raleway, Helvetica, Arial, sans-serif",
    "RobotoMono" => "RobotoMono, Helvetica, Arial, sans-serif",
    "Poppins" => "Poppins, Helvetica, Arial, sans-serif",
    "NotoSans" => "NotoSans, Helvetica, Arial, sans-serif",
    "RobotoSlab" => "RobotoSlab, Helvetica, Arial, sans-serif",
    "Merriweather" => "Merriweather, Helvetica, Arial, sans-serif",
    "Ubuntu" => "Ubuntu, Helvetica, Arial, sans-serif",
    "PTSans" => "PTSans, Helvetica, Arial, sans-serif",
    "PlayfairDisplay" => "PlayfairDisplay, Helvetica, Arial, sans-serif",
    "Nunito" => "Nunito, Helvetica, Arial, sans-serif",
    "Lora" => "Lora, Helvetica, Arial, sans-serif",
    "Mukta" => "Mukta, Helvetica, Arial, sans-serif"
  }

  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= FONTS.keys.map do |font_name|
      key = font_name.underscore.tr(" ", "_")
      { name: "base_font_setting.#{key}", value: font_name }
    end
  end

  def self.font_stack(font_name)
    FONTS[font_name]
  end

  def self.translate_names?
    true
  end

end

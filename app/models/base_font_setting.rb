# frozen_string_literal: true

require "enum_site_setting"

class BaseFontSetting < EnumSiteSetting

  FONTS = {
    "Helvetica" => { key: :default, font_stack: "Helvetica, Arial, sans-serif" },
    "Open Sans" => { key: :open_sans, font_stack: "Open Sans, Helvetica, Arial, sans-serif" },
    "Oxanium" => { key: :oxanium, font_stack: "Oxanium, Helvetica, Arial, sans-serif" },
    "Roboto" => { key: :roboto, font_stack: "Roboto, Helvetica, Arial, sans-serif" },
    "Lato" => { key: :lato, font_stack: "Lato, Helvetica, Arial, sans-serif" },
    "NotoSansJP" => { key: :noto_sans_jp, font_stack: "NotoSansJP, Helvetica, Arial, sans-serif" },
    "Montserrat" => { key: :montserrat, font_stack: "Montserrat, Helvetica, Arial, sans-serif" },
    "RobotoCondensed" => { key: :roboto_condensed, font_stack: "RobotoCondensed, Helvetica, Arial, sans-serif" },
    "SourceSansPro" => { key: :source_sans_pro, font_stack: "SourceSansPro, Helvetica, Arial, sans-serif" },
    "Oswald" => { key: :oswald, font_stack: "Oswald, Helvetica, Arial, sans-serif" },
    "Raleway" => { key: :raleway, font_stack: "Raleway, Helvetica, Arial, sans-serif" },
    "RobotoMono" => { key: :roboto_mono, font_stack: "RobotoMono, Helvetica, Arial, sans-serif" },
    "Poppins" => { key: :poppins, font_stack: "Poppins, Helvetica, Arial, sans-serif" },
    "NotoSans" => { key: :noto_sans, font_stack: "NotoSans, Helvetica, Arial, sans-serif" },
    "RobotoSlab" => { key: :roboto_slab, font_stack: "RobotoSlab, Helvetica, Arial, sans-serif" },
    "Merriweather" => { key: :merriweather, font_stack: "Merriweather, Helvetica, Arial, sans-serif" },
    "Ubuntu" => { key: :ubuntu, font_stack: "Ubuntu, Helvetica, Arial, sans-serif" },
    "PTSans" => { key: :pt_sans, font_stack: "PTSans, Helvetica, Arial, sans-serif" },
    "PlayfairDisplay" => { key: :play_fair_display, font_stack: "PlayfairDisplay, Helvetica, Arial, sans-serif" },
    "Nunito" => { key: :nunito, font_stack: "Nunito, Helvetica, Arial, sans-serif" },
    "Lora" => { key: :lora, font_stack: "Lora, Helvetica, Arial, sans-serif" },
    "Mukta" => { key: :mukta, font_stack: "Mukta, Helvetica, Arial, sans-serif" }
  }

  def self.valid_value?(val)
    values.any? { |v| v[:value].to_s == val.to_s }
  end

  def self.values
    @values ||= FONTS.map do |name, h|
      { name: "base_font_setting.#{h[:key]}", value: name }
    end
  end

  def self.font_stack(font_name)
    FONTS[font_name][:font_stack]
  end

  def self.translate_names?
    true
  end

end

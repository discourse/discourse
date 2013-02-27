module JsLocaleHelper

  def self.output_locale(locale)

    SimplesIdeias::I18n.assert_usable_configuration!

    s = "var I18n = I18n || {};"
    segment = "app/assets/javascripts/i18n/#{locale}.js"
    s += "I18n.translations = " + SimplesIdeias::I18n.translation_segments[segment].to_json + ";"

    segment = "app/assets/javascripts/i18n/admin.#{locale}.js"
    admin = SimplesIdeias::I18n.translation_segments[segment]
    admin[locale][:js] = admin[locale].delete(:admin_js)

    s += "jQuery.extend(true, I18n.translations, " + admin.to_json + ");"

    s

  end

end

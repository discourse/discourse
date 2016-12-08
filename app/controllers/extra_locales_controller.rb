class ExtraLocalesController < ApplicationController

  layout :false
  skip_before_filter :check_xhr, :preload_json

  def show
    bundle = params[:bundle]
    raise Discourse::InvalidAccess.new unless bundle =~ /^[a-z]+$/

    locale_str = I18n.locale.to_s
    translations = JsLocaleHelper.translations_for(locale_str)
    for_key = translations[locale_str]["#{bundle}_js"]
    js = ""

    if for_key.present?
      if plugin_for_key = JsLocaleHelper.plugin_translations(locale_str)["#{bundle}_js"]
        for_key.deep_merge!(plugin_for_key)
      end

      js = <<~JS
      (function() {
        if (window.I18n) {
          window.I18n.extras = window.I18n.extras || [];
          window.I18n.extras.push(#{for_key.to_json});
        }
      })();
      JS
    end

    render text: js, content_type: "application/javascript"
  end
end

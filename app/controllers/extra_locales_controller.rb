class ExtraLocalesController < ApplicationController

  layout :false
  skip_before_action :check_xhr, :preload_json

  def show
    bundle = params[:bundle]
    raise Discourse::InvalidAccess.new unless bundle =~ /^(admin|wizard)$/

    locale_str = I18n.locale.to_s
    bundle_str = "#{bundle}_js"

    translations = JsLocaleHelper.translations_for(locale_str)

    for_key = {}
    translations.values.each { |v| for_key.deep_merge!(v[bundle_str]) if v.has_key?(bundle_str) }

    js = ""

    if for_key.present?
      if plugin_for_key = JsLocaleHelper.plugin_translations(locale_str)[bundle_str]
        for_key.deep_merge!(plugin_for_key)
      end

      js = <<~JS.squish
        (function() {
          if (window.I18n) {
            window.I18n.extras = window.I18n.extras || [];
            window.I18n.extras.push(#{for_key.to_json});
          }
        })();
      JS
    end

    render plain: js, content_type: "application/javascript"
  end
end

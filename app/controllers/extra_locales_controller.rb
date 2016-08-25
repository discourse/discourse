class ExtraLocalesController < ApplicationController

  layout :false
  skip_before_filter :check_xhr, :preload_json

  def show
    locale_str = I18n.locale.to_s
    translations = JsLocaleHelper.translations_for(locale_str)

    bundle = params[:bundle]
    raise Discourse::InvalidAccess.new unless bundle =~ /^[a-z]+$/
    for_key = translations[locale_str]["#{bundle}_js"] 


    if for_key.present?
      js = <<-JS
        (function() {
          if (window.I18n) {
            window.I18n.extras = window.I18n.extras || [];
            window.I18n.extras.push(#{for_key.to_json});
          }
        })();
      JS
    else
      js = ""
    end


    render text: js, content_type: "application/javascript"
  end
end

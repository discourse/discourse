# frozen_string_literal: true

class ExtraLocalesController < ApplicationController
  layout :false

  skip_before_action :check_xhr,
    :preload_json,
    :redirect_to_login_if_required,
    :verify_authenticity_token

  def show
    bundle = params[:bundle]

    raise Discourse::InvalidAccess.new if bundle !~ /^(admin|wizard)$/ || !current_user&.staff?

    if params[:v]&.size == 32
      hash = ExtraLocalesController.bundle_js_hash(bundle)
      immutable_for(24.hours) if hash == params[:v]
    end

    render plain: ExtraLocalesController.bundle_js(bundle), content_type: "application/javascript"
  end

  def self.bundle_js_hash(bundle)
    @bundle_js_hash ||= {}
    @bundle_js_hash["#{bundle}_#{I18n.locale}"] ||= Digest::MD5.hexdigest(bundle_js(bundle))
  end

  def self.url(bundle)
    if Rails.env == "production"
      "#{Discourse.base_uri}/extra-locales/#{bundle}?v=#{bundle_js_hash(bundle)}"
    else
      "#{Discourse.base_uri}/extra-locales/#{bundle}"
    end
  end

  def self.bundle_js(bundle)
    locale_str = I18n.locale.to_s
    bundle_str = "#{bundle}_js"

    translations = JsLocaleHelper.translations_for(locale_str)

    translations.keys.each do |l|
      translations[l].keys.each do |k|
        bundle_translations = translations[l].delete(k)
        translations[l].deep_merge!(bundle_translations) if k == bundle_str
      end
    end

    js = ""

    if translations.present?
      js = <<~JS.squish
        (function() {
          if (window.I18n) {
            window.I18n.extras = #{translations.to_json};
          }
        })();
      JS
    end

    js
  end
end

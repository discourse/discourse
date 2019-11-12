# frozen_string_literal: true

class ExtraLocalesController < ApplicationController
  layout :false

  skip_before_action :check_xhr,
    :preload_json,
    :redirect_to_login_if_required,
    :verify_authenticity_token

  OVERRIDES_BUNDLE ||= 'overrides'
  MD5_HASH_LENGTH ||= 32

  def show
    bundle = params[:bundle]
    raise Discourse::InvalidAccess.new if !valid_bundle?(bundle)

    version = params[:v]
    if version.present?
      if version.kind_of?(String) && version.length == MD5_HASH_LENGTH
        hash = ExtraLocalesController.bundle_js_hash(bundle)
        immutable_for(1.year) if hash == version
      else
        raise Discourse::InvalidParameters.new(:v)
      end
    end

    render plain: ExtraLocalesController.bundle_js(bundle), content_type: "application/javascript"
  end

  def self.bundle_js_hash(bundle)
    if bundle == OVERRIDES_BUNDLE
      site = RailsMultisite::ConnectionManagement.current_db

      @by_site ||= {}
      @by_site[site] ||= {}
      @by_site[site][I18n.locale] ||= begin
        js = bundle_js(bundle)
        js.present? ? Digest::MD5.hexdigest(js) : nil
      end
    else
      @bundle_js_hash ||= {}
      @bundle_js_hash["#{bundle}_#{I18n.locale}"] ||= Digest::MD5.hexdigest(bundle_js(bundle))
    end
  end

  def self.url(bundle)
    "#{Discourse.base_uri}/extra-locales/#{bundle}?v=#{bundle_js_hash(bundle)}"
  end

  def self.client_overrides_exist?
    bundle_js_hash(OVERRIDES_BUNDLE).present?
  end

  def self.bundle_js(bundle)
    locale_str = I18n.locale.to_s
    bundle_str = "#{bundle}_js"

    if bundle == OVERRIDES_BUNDLE
      JsLocaleHelper.output_client_overrides(locale_str)
    else
      JsLocaleHelper.output_extra_locales(bundle_str, locale_str)
    end
  end

  def self.clear_cache!
    site = RailsMultisite::ConnectionManagement.current_db
    @by_site&.delete(site)
  end

  private

  def valid_bundle?(bundle)
    bundle == OVERRIDES_BUNDLE || (bundle =~ /^(admin|wizard)$/ && current_user&.staff?)
  end
end

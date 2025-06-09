# frozen_string_literal: true

class ExtraLocalesController < ApplicationController
  layout false

  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     :verify_authenticity_token

  before_action :is_asset_path, :apply_cdn_headers

  OVERRIDES_BUNDLE = "overrides"
  SHA1_HASH_LENGTH = 40
  MAIN_BUNDLE = "main"
  MF_BUNDLE = "mf"
  ADMIN_BUNDLE = "admin"
  WIZARD_BUNDLE = "wizard"
  CACHE_VERSION = 2

  SITE_SPECIFIC_BUNDLES = [OVERRIDES_BUNDLE, MF_BUNDLE]
  SHARED_BUNDLES = [MAIN_BUNDLE, ADMIN_BUNDLE, WIZARD_BUNDLE]

  class << self
    def js_digests
      @js_digests ||= { site_specific: {}, shared: {} }
    end

    def bundle_js_hash(bundle, locale:)
      bundle_key = "#{bundle}_#{locale}"
      if bundle.in?(SITE_SPECIFIC_BUNDLES)
        site = RailsMultisite::ConnectionManagement.current_db

        js_digests[:site_specific][site] ||= {}
        js_digests[:site_specific][site][bundle_key] ||= begin
          js = bundle_js(bundle, locale: locale)
          js.present? ? digest_for_content(js) : nil
        end
      elsif bundle.in?(SHARED_BUNDLES)
        js_digests[:shared][bundle_key] ||= digest_for_content(bundle_js(bundle, locale: locale))
      else
        raise "Unknown bundle: #{bundle}"
      end
    end

    def url(bundle, locale: I18n.locale)
      hash = bundle_js_hash(bundle, locale:)

      base = "#{GlobalSetting.cdn_url}#{Discourse.base_path}"
      path = "/extra-locales/#{hash}/#{locale}/#{bundle}.js"
      query = SITE_SPECIFIC_BUNDLES.include?(bundle) ? "?__ws=#{Discourse.current_hostname}" : ""
      "#{base}#{path}#{query}"
    end

    def client_overrides_exist?(locale: I18n.locale)
      bundle_js_hash(OVERRIDES_BUNDLE, locale: locale).present?
    end

    def bundle_js(bundle, locale:)
      locale_str = locale.to_s
      bundle_str = "#{bundle}_js"

      I18n.with_locale(locale) do
        case bundle
        when OVERRIDES_BUNDLE
          JsLocaleHelper.output_client_overrides(locale_str)
        when MF_BUNDLE
          JsLocaleHelper.output_MF(locale_str)
        when MAIN_BUNDLE
          JsLocaleHelper.output_locale(locale_str)
        else
          JsLocaleHelper.output_extra_locales(bundle_str, locale_str)
        end
      end
    end

    def bundle_js_with_hash(bundle, locale:)
      js = bundle_js(bundle, locale: locale)
      [js, digest_for_content(js)]
    end

    def clear_cache!(all_sites: false)
      site = RailsMultisite::ConnectionManagement.current_db
      if all_sites
        js_digests[:site_specific].clear
        js_digests[:shared].clear
      else
        js_digests[:site_specific].delete(site)
      end
    end

    def digest_for_content(js)
      Digest::SHA1.hexdigest("#{CACHE_VERSION}|#{js}")
    end
  end

  def show
    bundle = params[:bundle]
    raise Discourse::NotFound if !valid_bundle?(bundle)

    locale = params[:locale]
    raise Discourse::NotFound if !I18n.available_locales.include?(locale.to_sym)

    digest = params[:digest]
    if digest.present?
      raise Discourse::InvalidParameters.new(:digest) unless digest.to_s.size == SHA1_HASH_LENGTH
    end

    content, hash = ExtraLocalesController.bundle_js_with_hash(bundle, locale:)
    immutable_for(1.year) if hash == digest

    render plain: content, content_type: "application/javascript"
  end

  private

  def valid_bundle?(bundle)
    bundle.in?(SITE_SPECIFIC_BUNDLES) || bundle.in?(SHARED_BUNDLES)
  end
end

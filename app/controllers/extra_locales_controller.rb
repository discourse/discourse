# frozen_string_literal: true

class ExtraLocalesController < ApplicationController
  layout false

  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     :verify_authenticity_token

  OVERRIDES_BUNDLE = "overrides"
  SHA1_HASH_LENGTH = 40
  MF_BUNDLE = "mf"
  ADMIN_BUNDLE = "admin"
  WIZARD_BUNDLE = "wizard"

  SITE_SPECIFIC_BUNDLES = [OVERRIDES_BUNDLE, MF_BUNDLE]
  SHARED_BUNDLES = [ADMIN_BUNDLE, WIZARD_BUNDLE]

  class << self
    def js_digests
      @js_digests ||= { site_specific: {}, shared: {} }
    end

    def bundle_js_hash(bundle)
      bundle_key = "#{bundle}_#{I18n.locale}"
      if bundle.in?(SITE_SPECIFIC_BUNDLES)
        site = RailsMultisite::ConnectionManagement.current_db

        js_digests[:site_specific][site] ||= {}
        js_digests[:site_specific][site][bundle_key] ||= begin
          js = bundle_js(bundle)
          js.present? ? digest_for_content(js) : nil
        end
      elsif bundle.in?(SHARED_BUNDLES)
        js_digests[:shared][bundle_key] ||= digest_for_content(bundle_js(bundle))
      else
        raise "Unknown bundle: #{bundle}"
      end
    end

    def url(bundle)
      base = "#{GlobalSetting.cdn_url}#{Discourse.base_path}"
      path = "/extra-locales/#{bundle_js_hash(bundle)}/#{bundle}"
      query = SITE_SPECIFIC_BUNDLES.include?(bundle) ? "?__ws=#{Discourse.current_hostname}" : ""
      "#{base}#{path}#{query}"
    end

    def client_overrides_exist?
      bundle_js_hash(OVERRIDES_BUNDLE).present?
    end

    def bundle_js(bundle)
      locale_str = I18n.locale.to_s
      bundle_str = "#{bundle}_js"

      case bundle
      when OVERRIDES_BUNDLE
        JsLocaleHelper.output_client_overrides(locale_str)
      when MF_BUNDLE
        JsLocaleHelper.output_MF(locale_str)
      else
        JsLocaleHelper.output_extra_locales(bundle_str, locale_str)
      end
    end

    def bundle_js_with_hash(bundle)
      js = bundle_js(bundle)
      [js, digest_for_content(js)]
    end

    def clear_cache!
      site = RailsMultisite::ConnectionManagement.current_db
      js_digests[:site_specific].delete(site)
    end

    def digest_for_content(js)
      Digest::SHA1.hexdigest(js)
    end
  end

  def show
    bundle = params[:bundle]
    raise Discourse::InvalidAccess.new if !valid_bundle?(bundle)

    digest = params[:digest]
    if digest.present?
      raise Discourse::InvalidParameters.new(:digest) unless digest.to_s.size == SHA1_HASH_LENGTH
    end

    content, hash = ExtraLocalesController.bundle_js_with_hash(bundle)
    immutable_for(1.year) if hash == digest

    render plain: content, content_type: "application/javascript"
  end

  private

  def valid_bundle?(bundle)
    bundle.in?(SITE_SPECIFIC_BUNDLES) || bundle.in?(SHARED_BUNDLES)
  end
end

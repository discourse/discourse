class Admin::SiteTextsController < Admin::AdminController

  def self.preferred_keys
    ['system_messages.usage_tips.text_body_template',
     'education.new-topic',
     'education.new-reply',
     'login_required.welcome_message']
  end

  def index
    overridden = params[:overridden] == 'true'
    extras = {}

    query = params[:q] || ""
    if query.blank? && !overridden
      extras[:recommended] = true
      results = self.class.preferred_keys.map {|k| record_for(k) }
    else
      results = []
      translations = I18n.search(query, overridden: overridden)
      translations.each do |k, v|
        results << record_for(k, v)
      end

      results.sort! do |x, y|
        if x[:value].casecmp(query) == 0
          -1
        elsif y[:value].casecmp(query) == 0
          1
        else
          (x[:id].size + x[:value].size) <=> (y[:id].size + y[:value].size)
        end
      end
    end

    render_serialized(results[0..50], SiteTextSerializer, root: 'site_texts', rest_serializer: true, extras: extras)
  end

  def show
    site_text = find_site_text
    render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
  end

  def update
    site_text = find_site_text
    site_text[:value] = params[:site_text][:value]
    old_text = I18n.t(site_text[:id])
    StaffActionLogger.new(current_user).log_site_text_change(site_text[:id], site_text[:value], old_text)

    TranslationOverride.upsert!(I18n.locale, site_text[:id], site_text[:value])
    render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
  end

  def revert
    site_text = find_site_text
    old_text = I18n.t(site_text[:id])
    TranslationOverride.revert!(I18n.locale, site_text[:id])
    site_text = find_site_text
    StaffActionLogger.new(current_user).log_site_text_change(site_text[:id], site_text[:value], old_text)
    render_serialized(site_text, SiteTextSerializer, root: 'site_text', rest_serializer: true)
  end

  protected

    def record_for(k, value=nil)
      if k.ends_with?("_MF")
        ovr = TranslationOverride.where(translation_key: k).pluck(:value)
        value = ovr[0] if ovr.present?
      end

      value ||= I18n.t(k)
      {id: k, value: value}
    end

    def find_site_text
      raise Discourse::NotFound unless I18n.exists?(params[:id])
      record_for(params[:id])
    end

end

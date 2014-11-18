module SiteTextClassMethods

  def text_types
    @types || []
  end

  def find_text_type(ct)
    SiteText.text_types.find {|t| t.text_type == ct.to_sym}
  end

  def add_text_type(text_type, opts=nil)
    opts ||= {}
    @types ||= []
    format = opts[:format] || :markdown
    @types << SiteTextType.new(text_type, format, opts)
  end

  def text_for_cache
    @text_for_cache ||= DistributedCache.new("text_for_cache")
  end

  def text_for(text_type, replacements=nil)
    text = nil
    text = text_for_cache[text_type] if replacements.blank?
    text ||= uncached_text_for(text_type, replacements)
  end

  def uncached_text_for(text_type, replacements=nil)
    store_cache = replacements.blank?

    replacements ||= {}
    replacements = {site_name: SiteSetting.title}.merge!(replacements)
    replacements = SiteSetting.settings_hash.merge!(replacements)

    site_text = SiteText.select(:value).find_by(text_type: text_type)

    result = ""
    if site_text.blank?
      ct = find_text_type(text_type)
      result = ct.default_text.dup if ct.present?
    else
      result = site_text.value.dup
    end

    result.gsub!(/\%\{[^}]+\}/) do |m|
      replacements[m[2..-2].to_sym] || m
    end

    if store_cache
      result.freeze
      text_for_cache[text_type] = result
    end

    result
  end

  def find_or_new(text_type)
    site_text = SiteText.find_by(text_type: text_type)
    return site_text if site_text.present?

    site_text = SiteText.new
    site_text.text_type = text_type
    site_text
  end

end

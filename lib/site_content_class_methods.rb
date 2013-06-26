module SiteContentClassMethods

  def content_types
    @types || []
  end

  def find_content_type(ct)
    SiteContent.content_types.find {|t| t.content_type == ct.to_sym}
  end

  def add_content_type(content_type, opts=nil)
    opts ||= {}
    @types ||= []
    format = opts[:format] || :markdown
    @types << SiteContentType.new(content_type, format, opts)
  end

  def content_for(content_type, replacements=nil)
    replacements ||= {}
    replacements = {site_name: SiteSetting.title}.merge!(replacements)
    replacements = SiteSetting.settings_hash.merge!(replacements)

    site_content = SiteContent.select(:content).where(content_type: content_type).first

    result = ""
    if site_content.blank?
      ct = find_content_type(content_type)
      result = ct.default_content if ct.present?
    else
      result = site_content.content
    end

    result.gsub!(/\%\{[^}]+\}/) do |m|
      replacements[m[2..-2].to_sym] || m
    end

    result
  end


  def find_or_new(content_type)
    site_content = SiteContent.where(content_type: content_type).first
    return site_content if site_content.present?

    site_content = SiteContent.new
    site_content.content_type = content_type
    site_content
  end

end

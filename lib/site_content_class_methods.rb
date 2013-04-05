module SiteContentClassMethods

  def content_types
    @types || []
  end

  def content_type(content_type, format, opts=nil)
    opts ||= {}
    @types ||= []
    @types << SiteContentType.new(content_type, format, opts)
  end

  def content_for(content_type, replacements=nil)
    replacements ||= {}

    site_content = SiteContent.select(:content).where(content_type: content_type).first
    return "" if site_content.blank?

    site_content.content % replacements
  end


  def find_or_new(content_type)
    site_content = SiteContent.where(content_type: content_type).first
    return site_content if site_content.present?

    site_content = SiteContent.new
    site_content.content_type = content_type
    site_content
  end

end

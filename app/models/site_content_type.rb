class SiteContentType

  attr_accessor :content_type, :format

  def initialize(content_type, format, opts=nil)
    @opts = opts || {}
    @content_type = content_type
    @format = format
  end

  def title
    I18n.t("content_types.#{content_type}.title")
  end

  def description
    I18n.t("content_types.#{content_type}.description")
  end

  def allow_blank?
    !!@opts[:allow_blank]
  end

  def default_content
    if @opts[:default_18n_key].present?
      return I18n.t(@opts[:default_18n_key])
    end
    ""
  end

end
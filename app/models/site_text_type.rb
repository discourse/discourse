class SiteTextType

  attr_accessor :text_type, :format

  def initialize(text_type, format, opts=nil)
    @opts = opts || {}
    @text_type = text_type
    @format = format
  end

  def title
    I18n.t("content_types.#{text_type}.title")
  end

  def description
    I18n.t("content_types.#{text_type}.description")
  end

  def allow_blank?
    !!@opts[:allow_blank]
  end

  def default_text
    @opts[:default_18n_key].present? ? I18n.t(@opts[:default_18n_key]) : ""
  end

end

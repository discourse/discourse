class SiteTextSerializer < ApplicationSerializer

  attributes :text_type,
             :title,
             :description,
             :value,
             :format,
             :allow_blank?

  def title
    object.site_text_type.title
  end

  def text_type
    object.text_type
  end

  def description
    object.site_text_type.description
  end

  def format
    object.site_text_type.format
  end

  def value
    return object.value if object.value.present?
    object.site_text_type.default_text
  end

  def allow_blank?
    object.site_text_type.allow_blank?
  end
end

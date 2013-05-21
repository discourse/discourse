class SiteContentSerializer < ApplicationSerializer

  attributes :content_type,
             :title,
             :description,
             :content,
             :format

  def title
    object.site_content_type.title
  end

  def description
    object.site_content_type.description
  end

  def format
    object.site_content_type.format
  end

  def content
    return object.content if object.content.present?
    object.site_content_type.default_content
  end
end

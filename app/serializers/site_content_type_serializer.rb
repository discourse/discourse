class SiteContentTypeSerializer < ApplicationSerializer

  attributes :content_type, :title

  def content_type
    object.content_type
  end

  def title
    object.title
  end

end

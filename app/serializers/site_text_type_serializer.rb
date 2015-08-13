class SiteTextTypeSerializer < ApplicationSerializer

  attributes :id, :text_type, :title

  def id
    text_type
  end

  def text_type
    object.text_type
  end

  def title
    object.title
  end

end

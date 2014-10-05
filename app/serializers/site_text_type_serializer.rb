class SiteTextTypeSerializer < ApplicationSerializer

  attributes :text_type, :title

  def text_type
    object.text_type
  end

  def title
    object.title
  end

end

# frozen_string_literal: true

class SidebarSectionSerializer < ApplicationSerializer
  attributes :id, :title, :links, :slug, :public, :section_type, :locale

  has_many :localizations, embed: :objects, serializer: SidebarSectionLocalizationSerializer

  def links
    object.sidebar_urls.map do |sidebar_url|
      SidebarUrlSerializer.new(
        sidebar_url,
        root: false,
        scope: scope,
        show_translated_name: show_translated_sidebar_url?(sidebar_url),
      ).as_json
    end
  end

  def title
    if ContentLocalization.show_translated_sidebar_section?(object, scope)
      object.get_localization&.title || object.title
    else
      object.title
    end
  end

  def slug
    object.title.parameterize
  end

  def include_localizations?
    false
  end

  private

  def show_translated_sidebar_url?(sidebar_url)
    return false if !object.public?
    return true if object.custom_section?

    object.community_section? && !sidebar_url.built_in_community_section_link?
  end
end

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
        show_translated_name: object.public?,
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
    object.localizations.loaded? && scope.can_edit_sidebar_section?(object)
  end
end

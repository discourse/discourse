# frozen_string_literal: true

class SidebarSectionEditSerializer < SidebarSectionSerializer
  def title
    object.title
  end

  def links
    object.sidebar_urls.map do |sidebar_url|
      SidebarUrlSerializer.new(
        sidebar_url,
        root: false,
        scope: scope,
        include_localizations: can_localize_sidebar_url?(sidebar_url),
        can_localize: can_localize_sidebar_url?(sidebar_url),
      ).as_json
    end
  end

  def include_localizations?
    object.localizations.loaded? && scope.can_localize_sidebar_section_title?(object)
  end

  private

  def can_localize_sidebar_url?(sidebar_url)
    scope.can_localize_sidebar_section_link?(object, sidebar_url.value)
  end
end

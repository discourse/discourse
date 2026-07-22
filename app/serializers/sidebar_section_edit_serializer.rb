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
        include_localizations: scope.can_localize_sidebar_section?(object),
      ).as_json
    end
  end

  def include_localizations?
    object.localizations.loaded? && scope.can_localize_sidebar_section?(object)
  end
end

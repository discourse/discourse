# frozen_string_literal: true

class SidebarSectionSerializer < ApplicationSerializer
  attributes :id, :title, :links, :slug

  def links
    object.sidebar_section_links.map(&:linkable)
  end

  def slug
    object.title.parameterize
  end
end

# frozen_string_literal: true

class SidebarSectionSerializer < ApplicationSerializer
  attributes :id, :title, :links, :slug, :public, :system

  def links
    object.sidebar_section_links.map { |link| SidebarUrlSerializer.new(link.linkable, root: false) }
  end

  def slug
    object.title.parameterize
  end
end

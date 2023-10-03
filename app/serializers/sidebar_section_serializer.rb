# frozen_string_literal: true

class SidebarSectionSerializer < ApplicationSerializer
  attributes :id, :title, :links, :slug, :public, :section_type

  def links
    object.sidebar_urls.map { |sidebar_url| SidebarUrlSerializer.new(sidebar_url, root: false) }
  end

  def slug
    object.title.parameterize
  end
end

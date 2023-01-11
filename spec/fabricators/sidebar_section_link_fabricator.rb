# frozen_string_literal: true

Fabricator(:sidebar_section_link) { user }

Fabricator(:category_sidebar_section_link, from: :sidebar_section_link) do
  linkable(fabricator: :category)
end

Fabricator(:tag_sidebar_section_link, from: :sidebar_section_link) { linkable(fabricator: :tag) }

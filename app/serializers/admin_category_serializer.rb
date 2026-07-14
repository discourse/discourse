# frozen_string_literal: true

class AdminCategorySerializer < ApplicationSerializer
  attributes :id,
             :badge_chain,
             :category_types,
             :description_text,
             :read_restricted,
             :topic_count,
             :edit_url

  def badge_chain
    ancestors
      .push(object)
      .map { |category| AdminCategoryBadgeSerializer.new(category, scope:, root: false).as_json }
  end

  def category_types
    Categories::TypeRegistry
      .all
      .values
      .select { |type| type.category_matches?(object) }
      .map { |type| { id: type.type_id, name: type.metadata(guardian: scope)[:name] } }
  end

  def edit_url
    "#{object.slug_url_without_id}/edit/general"
  end

  private

  def ancestors
    ancestors = []
    parent = object.parent_category

    while parent.present?
      ancestors.unshift(parent)
      parent = parent.parent_category
    end

    ancestors
  end
end

class BasicCategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :text_color,
             :slug,
             :topic_count,
             :post_count,
             :position,
             :description,
             :description_text,
             :topic_url,
             :logo_url,
             :background_url,
             :read_restricted,
             :permission,
             :parent_category_id,
             :notification_level,
             :can_edit,
             :topic_template,
             :has_children

  def include_parent_category_id?
    parent_category_id
  end

  def description
    object.uncategorized? ? I18n.t('category.uncategorized_description') : object.description
  end

  def can_edit
    true
  end

  def include_can_edit?
    scope && scope.can_edit?(object)
  end

  def notification_level
    object.notification_level
  end
end

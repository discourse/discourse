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
             :read_restricted,
             :permission,
             :parent_category_id,
             :notification_level,
             :can_edit,
             :topic_template,
             :has_children,
             :sort_order,
             :sort_ascending,
             :show_subcategory_list,
             :num_featured_topics,
             :default_view,
             :subcategory_list_style,
             :default_top_period,
             :minimum_required_tags

  has_one :uploaded_logo, embed: :object, serializer: CategoryUploadSerializer
  has_one :uploaded_background, embed: :object, serializer: CategoryUploadSerializer

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

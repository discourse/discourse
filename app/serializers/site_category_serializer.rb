# frozen_string_literal: true

class SiteCategorySerializer < BasicCategorySerializer
  include CategoryTaggingMixin

  attributes :read_only_banner, :form_template_ids

  has_many embed: :objects

  def name
    super_name = super
    modified =
      DiscoursePluginRegistry.apply_modifier(:site_category_serializer_name, super_name, self)
    modified || super_name
  end

  def form_template_ids
    object.form_template_ids.sort
  end
end

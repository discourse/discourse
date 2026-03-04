# frozen_string_literal: true

class Category::Action::EagerLoadAssociations < Service::ActionBase
  option :categories, []
  option :guardian

  ASSOCIATIONS = [
    :uploaded_logo,
    :uploaded_logo_dark,
    :uploaded_background,
    :uploaded_background_dark,
    :tags,
    :tag_groups,
    :form_templates,
    { category_required_tag_groups: :tag_group },
  ].freeze

  def call
    return if categories.blank?
    preload_associations
    preload_custom_fields
    preload_user_fields
  end

  private

  def preload_associations
    ActiveRecord::Associations::Preloader.new(records: categories, associations: ASSOCIATIONS).call
  end

  def preload_custom_fields
    return if Site.preloaded_category_custom_fields.blank?
    Category.preload_custom_fields(categories, Site.preloaded_category_custom_fields)
  end

  def preload_user_fields
    Category.preload_user_fields!(guardian, categories)
  end
end

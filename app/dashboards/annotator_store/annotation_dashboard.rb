require "administrate/base_dashboard"

module AnnotatorStore
  class AnnotationDashboard < Administrate::BaseDashboard
    # ATTRIBUTE_TYPES
    # a hash that describes the type of each of the model's fields.
    #
    # Each different type represents an Administrate::Field object,
    # which determines how the attribute is displayed
    # on pages throughout the dashboard.
    ATTRIBUTE_TYPES = {
      creator: Administrate::UserField,
      tag: Administrate::ParentTagField.with_options(class_name: 'AnnotatorStore::Tag'),
      id: Field::Number,
      uri: Field::String,
      tag_id: Field::Number,
      quote: Field::Text.with_options(truncate: 1000),
      creator_id: Field::Number,
      created_at: Field::DateTime,
      updated_at: Field::DateTime,
    }.freeze

    # COLLECTION_ATTRIBUTES
    # an array of attributes that will be displayed on the model's index page.
    #
    # By default, it's limited to four items to reduce clutter on index pages.
    # Feel free to add, remove, or rearrange items.
    COLLECTION_ATTRIBUTES = [
      :id,
      :quote,
      :tag,
      :creator,
    ].freeze

    # # SHOW_PAGE_ATTRIBUTES
    # # an array of attributes that will be displayed on the model's show page.
    SHOW_PAGE_ATTRIBUTES = [
      :id,
      :quote,
      :tag,
      :creator,
      :created_at,
      :updated_at,
    ].freeze

    # # FORM_ATTRIBUTES
    # # an array of attributes that will be displayed
    # # on the model's form (`new` and `edit`) pages.
    FORM_ATTRIBUTES = [
      :creator,
    ].freeze

    # Overwrite this method to customize how tags are displayed
    # across all pages of the admin dashboard.
    def display_resource(tag)
      "Annotation ##{tag.id}"
    end

  end
end

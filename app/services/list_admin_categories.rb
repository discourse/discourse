# frozen_string_literal: true

class ListAdminCategories
  include Service::Base

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  params do
    attribute :type, :string, default: "discussion"
    attribute :filter, :string
    attribute :visibility, :string
    attribute :per_page, :integer, default: DEFAULT_PER_PAGE
    attribute :page, :integer, default: 0

    validates :per_page,
              numericality: {
                greater_than_or_equal_to: 1,
                less_than_or_equal_to: MAX_PER_PAGE,
              }
    validates :page, numericality: { greater_than_or_equal_to: 0 }

    after_validation { self.type = type.presence || "discussion" }

    def type_id
      type
    end
  end

  model :category_type, optional: true
  policy :category_type_exists
  model :categories, optional: true
  model :category_page, :paginate_categories
  step :preload_category_custom_fields

  private

  def fetch_category_type(params:)
    return if params.type_id == "all"

    Categories::TypeRegistry.get(params.type_id)
  end

  def category_type_exists(params:, category_type:)
    params.type_id == "all" || category_type.present?
  end

  def fetch_categories(guardian:, params:, category_type:)
    categories =
      Category
        .secured(guardian)
        .includes(:parent_category)
        .for_category_type(params.type_id, category_type)

    categories = categories.matching_name_or_slug_ref(params.filter) if params.filter.present?

    if params.visibility.present?
      categories =
        case params.visibility
        when "public"
          categories.where(read_restricted: false)
        when "restricted"
          categories.where(read_restricted: true)
        else
          categories
        end
    end

    categories.order(Category.normalize_sql("categories.name"), "categories.id ASC")
  end

  def paginate_categories(categories:, params:)
    paginated_categories =
      categories.offset(params.page * params.per_page).limit(params.per_page + 1).to_a

    {
      categories: paginated_categories.take(params.per_page),
      has_more: paginated_categories.length > params.per_page,
    }
  end

  def preload_category_custom_fields(category_page:)
    return if Site.preloaded_category_custom_fields.blank? || category_page[:categories].blank?

    Category.preload_custom_fields(
      category_page[:categories],
      Site.preloaded_category_custom_fields,
    )
  end
end

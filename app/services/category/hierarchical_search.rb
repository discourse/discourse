# frozen_string_literal: true

class Category::HierarchicalSearch
  include Service::Base

  params do
    attribute :term, :string, default: ""
    attribute :only, :array, default: [], compact_blank: true
    attribute :except, :array, default: [], compact_blank: true
    attribute :page, :integer, default: 1

    validates :page, numericality: { greater_than: 0 }

    after_validation do
      self.term = term.to_s.strip[0, CategoriesController::MAX_CATEGORY_SEARCH_TERM_LENGTH].rstrip
    end

    def limit = CategoriesController::MAX_CATEGORIES_LIMIT
    def offset = (page - 1) * limit
  end

  model :categories, optional: true
  step :eager_load_associations

  private

  def fetch_categories(guardian:, params:)
    Category::Query::HierarchicalSearch.new(guardian:, params:).call
  end

  def eager_load_associations(guardian:, categories:)
    Category::Action::EagerLoadAssociations.call(categories:, guardian:)
  end
end

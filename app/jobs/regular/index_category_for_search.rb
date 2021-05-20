# frozen_string_literal: true

class Jobs::IndexCategoryForSearch < Jobs::Base
  def execute(args)
    category = Category.find_by(id: args[:category_id])
    return if category.blank?

    SearchIndexer.index(category, force: args[:force] || false)
  end
end

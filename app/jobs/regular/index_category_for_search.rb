# frozen_string_literal: true

class Jobs::IndexCategoryForSearch < Jobs::Base
  def execute(args)
    category = Category.find_by(id: args[:category_id])
    raise Discourse::InvalidParameters.new(:category_id) if category.blank?

    SearchIndexer.index(category, force: args[:force] || false)
  end
end

# frozen_string_literal: true

class CategoryDestroyer
  def self.destroy(guardian, category)
    Category.transaction do
      category.lock!
      guardian.ensure_can_delete!(category)
      StaffActionLogger.new(guardian.user).log_category_deletion(category)
      category.destroy!
    end

    Discourse.cache.delete(Categories::TypeRegistry::COUNTS_CACHE_KEY)
    category
  end
end

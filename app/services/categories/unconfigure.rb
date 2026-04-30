# frozen_string_literal: true

module Categories
  class Unconfigure
    include Service::Base

    params do
      attribute :category_id, :integer
      attribute :category_type, :string

      validates :category_id, presence: true
      validates :category_type, presence: true
      validate :category_type_is_valid

      def category_type_is_valid
        return if category_type.blank?
        return if Categories::TypeRegistry.valid?(category_type)

        errors.add(:category_type, :invalid)
      end
    end

    model :category
    policy :can_modify_category
    model :type_class

    step :unconfigure_category
    step :log_action
    step :clear_category_type_counts_cache

    private

    def fetch_category(params:)
      Category.find_by(id: params.category_id)
    end

    def can_modify_category(guardian:, category:)
      guardian.can_edit_category?(category)
    end

    def fetch_type_class(params:)
      Categories::TypeRegistry.get(params.category_type)
    end

    def unconfigure_category(type_class:, category:, guardian:)
      type_class.unconfigure_category(category, guardian:)
    end

    def log_action(guardian:, category:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "unconfigure_category_type",
        { category_id: category.id, category_type: params.category_type },
      )
    end

    def clear_category_type_counts_cache
      Discourse.cache.delete(Categories::TypeRegistry::COUNTS_CACHE_KEY)
    end
  end
end

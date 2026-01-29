# frozen_string_literal: true

module Categories
  class Configure
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
    policy :type_is_available

    transaction do
      step :enable_plugin
      step :configure_site_settings
      step :configure_category
    end

    step :log_action

    private

    def fetch_category(params:)
      Category.find_by(id: params.category_id)
    end

    def can_modify_category(guardian:, category:)
      guardian.can_edit_category?(category)
    end

    def type_is_available(params:)
      type_class(params).available?
    end

    def enable_plugin(params:)
      type_class(params).enable_plugin
    end

    def configure_site_settings(params:, category:)
      type_class(params).configure_site_settings(category)
    end

    def configure_category(params:, category:)
      type_class(params).configure_category(category)
    end

    def log_action(guardian:, category:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "configure_category_type",
        { category_id: category.id, category_type: params.category_type },
      )
    end

    def type_class(params)
      Categories::TypeRegistry.get!(params.category_type)
    end
  end
end

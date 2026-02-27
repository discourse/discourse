# frozen_string_literal: true

module Categories
  class Configure
    include Service::Base

    params do
      attribute :category_id, :integer
      attribute :category_type, :string
      attribute :configuration_values

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
    model :type_class
    policy :can_modify_category

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

    def fetch_type_class(params:)
      Categories::TypeRegistry.get(params.category_type)
    end

    def enable_plugin(type_class:)
      type_class.enable_plugin
    end

    def configure_site_settings(type_class:, category:, params:)
      type_class.configure_site_settings(
        category,
        configuration_values: params.configuration_values || {},
      )
    end

    def configure_category(type_class:, category:, params:)
      type_class.configure_category(
        category,
        configuration_values: params.configuration_values || {},
      )
    end

    def log_action(guardian:, category:, params:)
      StaffActionLogger.new(guardian.user).log_custom(
        "configure_category_type",
        { category_id: category.id, category_type: params.category_type },
      )
    end
  end
end

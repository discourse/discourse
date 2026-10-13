# frozen_string_literal: true

class CategoryUpdater
  MAX_DESCRIPTION_LENGTH = CategoryCreator::MAX_DESCRIPTION_LENGTH

  def self.update(
    guardian,
    category,
    attributes = nil,
    log_attributes: nil,
    old_permissions: nil,
    old_custom_fields: nil,
    **attribute_keywords
  )
    attributes = attributes ? attributes.to_h.merge(attribute_keywords) : attribute_keywords

    new(
      guardian,
      category,
      attributes,
      log_attributes:,
      old_permissions:,
      old_custom_fields:,
    ).update
  end

  def initialize(
    guardian,
    category,
    attributes,
    log_attributes: nil,
    old_permissions: nil,
    old_custom_fields: nil
  )
    @guardian = guardian
    @category = category
    @attributes = attributes.to_h.with_indifferent_access
    @log_attributes = (log_attributes || attributes).to_h.with_indifferent_access
    @old_permissions = old_permissions
    @old_custom_fields = old_custom_fields
  end

  def update
    guardian.ensure_can_edit!(category)

    if attributes[:parent_category_id].present?
      parent_category = Category.find_by(id: attributes[:parent_category_id])
      guardian.ensure_can_edit!(parent_category) if parent_category.present?
    end

    if attributes[:description].present? && attributes[:description].length > MAX_DESCRIPTION_LENGTH
      category.errors.add(
        :base,
        I18n.t("category.errors.description_too_long", count: MAX_DESCRIPTION_LENGTH),
      )
      return false
    end

    Category.transaction do
      begin
        updated = category.update(attributes)
      rescue ArgumentError => error
        category.errors.add(:base, error.message)
        return false
      end

      if updated
        StaffActionLogger.new(guardian.user).log_category_settings_change(
          category,
          log_attributes,
          old_permissions:,
          old_custom_fields:,
        )
      end

      updated
    end
  end

  private

  attr_reader :guardian,
              :category,
              :attributes,
              :log_attributes,
              :old_permissions,
              :old_custom_fields
end

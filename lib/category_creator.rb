# frozen_string_literal: true

class CategoryCreator
  MAX_DESCRIPTION_LENGTH = 1_000

  def self.create(guardian, attributes)
    new(guardian, attributes).create
  end

  def initialize(guardian, attributes)
    @guardian = guardian
    @attributes = attributes.to_h.with_indifferent_access
  end

  def create
    guardian.ensure_can_create!(Category)

    category = Category.new
    begin
      category.assign_attributes(attributes.merge(user: guardian.user))
    rescue ArgumentError => error
      category.errors.add(:base, error.message)
      return category
    end

    if category.parent_category_id.present? && category.parent_category.present?
      guardian.ensure_can_edit!(category.parent_category)
    end

    if attributes[:description].present? && attributes[:description].length > MAX_DESCRIPTION_LENGTH
      category.errors.add(
        :base,
        I18n.t("category.errors.description_too_long", count: MAX_DESCRIPTION_LENGTH),
      )
      return category
    end

    Category.transaction do
      StaffActionLogger.new(guardian.user).log_category_creation(category) if category.save
    end

    category
  end

  private

  attr_reader :guardian, :attributes
end

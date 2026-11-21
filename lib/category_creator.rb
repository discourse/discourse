# frozen_string_literal: true

class CategoryCreator
  MAX_DESCRIPTION_LENGTH = 1_000

  def self.create(guardian, attributes)
    new(guardian, attributes).create
  end

  def self.create_subcategory_as_group_moderator(guardian, parent, attributes)
    new(guardian, attributes).create(parent_for_group_moderator: parent)
  end

  def initialize(guardian, attributes)
    @guardian = guardian
    @attributes = attributes.to_h.with_indifferent_access
  end

  def create(parent_for_group_moderator: nil)
    category = Category.new
    if parent_for_group_moderator
      guardian.ensure_can_create_subcategory_as_group_moderator!(parent_for_group_moderator)
      inherit_parent_permissions(category, parent_for_group_moderator)
      category_attributes =
        attributes.slice(:name).merge(
          parent_category: parent_for_group_moderator,
          color: parent_for_group_moderator.color,
          text_color: parent_for_group_moderator.text_color,
        )
    else
      guardian.ensure_can_create!(Category)
      category_attributes = attributes
    end

    begin
      category.assign_attributes(category_attributes.merge(user: guardian.user))
    rescue ArgumentError => error
      category.errors.add(:base, error.message)
      return category
    end

    if !parent_for_group_moderator && category.parent_category_id.present? &&
         category.parent_category.present?
      guardian.ensure_can_edit!(category.parent_category)
    end

    if category_attributes[:description].present? &&
         category_attributes[:description].length > MAX_DESCRIPTION_LENGTH
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

  def inherit_parent_permissions(category, parent)
    category.read_restricted = parent.read_restricted
    category.category_groups = parent.category_groups.map(&:dup)
    category.moderating_group_ids = parent.moderating_group_ids
    if (setting = parent.category_setting)
      category.build_category_setting(
        topic_posting_review_mode: setting.topic_posting_review_mode,
        reply_posting_review_mode: setting.reply_posting_review_mode,
      )
      category.topic_posting_review_group_ids = parent.topic_posting_review_group_ids
      category.reply_posting_review_group_ids = parent.reply_posting_review_group_ids
    end
  end

  attr_reader :guardian, :attributes
end

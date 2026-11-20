# frozen_string_literal: true

class TopicCategoryChangeValidator
  Result =
    Data.define(:category, :error, :status) do
      def success?
        error.nil?
      end
    end

  def self.call(topic:, category_id:, guardian:, tag_names:, tags_changed:)
    category = category_id.to_i.zero? ? nil : Category.find_by(id: category_id)

    if topic.shared_draft
      return failure(I18n.t("category.errors.not_found")) if category.blank?

      guardian.ensure_can_publish_topic!(topic, category)
      return success(category)
    end

    return failure(I18n.t("category.errors.not_found")) if category_id.to_i != 0 && category.blank?

    begin
      guardian.ensure_can_move_topic_to_category!(category)
    rescue Discourse::InvalidAccess
      return failure(I18n.t("category.errors.move_topic_to_category_disallowed"), :forbidden)
    end

    return success(category) if category.blank? || tag_names.blank?

    allowed_tag_names = DiscourseTagging.filter_allowed_tags(guardian, category:).map(&:name)
    invalid_tag_names = tag_names - allowed_tag_names
    hidden_tag_names = DiscourseTagging.hidden_tag_names(guardian)
    invalid_tag_names -= hidden_tag_names if !tags_changed
    invalid_tag_names = Tag.where_name(invalid_tag_names).pluck(:name)
    return success(category) if invalid_tag_names.empty?

    error =
      if (invalid_tag_names & hidden_tag_names).present?
        I18n.t("category.errors.disallowed_tags_generic")
      else
        I18n.t("category.errors.disallowed_topic_tags", tags: invalid_tag_names.join(", "))
      end
    failure(error)
  end

  def self.safe_revision_errors(topic:, guardian:, category_changed:)
    if category_changed
      visible_tag_ids = DiscourseTagging.visible_tag_ids(topic.tags, guardian)
      if topic.tags.any? { |tag| visible_tag_ids.exclude?(tag.id) }
        return [I18n.t("category.errors.disallowed_tags_generic")]
      end
    end

    topic.errors.full_messages
  end

  def self.success(category)
    Result.new(category:, error: nil, status: nil)
  end
  private_class_method :success

  def self.failure(error, status = :unprocessable_entity)
    Result.new(category: nil, error:, status:)
  end
  private_class_method :failure
end

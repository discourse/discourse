# frozen_string_literal: true

class TagGroupUpdater
  def self.update(guardian, tag_group, attributes, partial: false)
    guardian.ensure_can_admin_tag_groups!
    TagGroup.transaction do
      tag_group.lock!
      old_data = TagGroupSerializer.new(tag_group).to_json(root: false)
      updated = tag_group.update(parameters(attributes, partial:))
      raise ActiveRecord::Rollback unless updated
      StaffActionLogger.new(guardian.user).log_tag_group_change(
        tag_group.name,
        old_data,
        TagGroupSerializer.new(tag_group).to_json(root: false),
      )
      true
    end || false
  end

  def self.parameters(attributes, partial: false)
    params = ActionController::Parameters.new(attributes.to_h)
    result =
      params.permit(
        :name,
        :one_per_topic,
        tags: %i[id name slug],
        tag_names: [],
        parent_tag: %i[id name slug],
        parent_tag_name: [],
        permissions: {
        },
      )

    if result[:tags].present?
      result[:tag_ids] = result[:tags].filter_map { |t| t["id"] }

      new_tag_names = result[:tags].filter_map { |t| t["name"] if t["id"].blank? }

      if new_tag_names.present?
        result[:tag_ids].concat(
          DiscourseTagging.find_or_create_tags!(
            new_tag_names,
            Guardian.new(Discourse.system_user),
            unlimited: true,
          ).map(&:id),
        )
      end
    elsif result[:tag_names].present?
      Discourse.deprecate(
        "the tag_names param is deprecated, use tags instead",
        since: "2026.01",
        drop_from: "2026.07",
      )
    elsif !partial || params.key?(:tags) || params.key?(:tag_names)
      result[:tag_names] = []
    end
    result.delete(:tags)

    if result[:parent_tag].present?
      parent = result[:parent_tag].first

      if parent&.dig("id").present?
        result[:parent_tag_id] = parent["id"]
      elsif parent&.dig("name").present?
        tag =
          DiscourseTagging.find_or_create_tags!(
            [parent["name"]],
            Guardian.new(Discourse.system_user),
            unlimited: true,
          ).first

        result[:parent_tag_id] = tag.id if tag
      end
    elsif result[:parent_tag_name].present?
      Discourse.deprecate(
        "the parent_tag_name param is deprecated, use parent_tag instead",
        since: "2026.01",
        drop_from: "2026.07",
      )
    elsif !partial || params.key?(:parent_tag) || params.key?(:parent_tag_name)
      result[:parent_tag_name] = []
    end
    result.delete(:parent_tag)

    if !partial || params.key?(:one_per_topic)
      result[:one_per_topic] = params[:one_per_topic].in?([true, "true"])
    end

    result
  end
end

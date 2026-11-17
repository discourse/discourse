# frozen_string_literal: true

module DiscourseWorkflows
  module EntitySerializers
    module_function

    def serialize_record(
      record,
      serializer,
      scope: Discourse.system_user.guardian,
      root: false,
      **opts
    )
      MultiJson.load(serializer.new(record, scope:, root:, **opts).to_json).deep_symbolize_keys
    end

    def serialize_post(
      post,
      guardian: Discourse.system_user.guardian,
      include_raw: true,
      include_cooked: false
    )
      return if post.blank?

      serialize_record(
        post,
        DiscourseWorkflows::PostSerializer,
        scope: guardian,
        include_raw:,
        include_cooked:,
      )
    end

    def serialize_topic(topic, guardian: Discourse.system_user.guardian, custom_field_names: [])
      serialize_record(
        topic,
        DiscourseWorkflows::TopicSerializer,
        scope: guardian,
        custom_field_names:,
      )
    end

    def serialize_topic_list_item(topic, scope: Discourse.system_user.guardian)
      serialize_record(topic, DiscourseWorkflows::TopicListItemSerializer, scope:)
    end

    def serialize_user(user, guardian: Discourse.system_user.guardian)
      return if user.blank?

      serialize_record(user, DiscourseWorkflows::UserSerializer, scope: guardian)
    end

    def serialize_basic_group(group)
      { id: group.id, name: group.name, full_name: group.full_name, automatic: group.automatic? }
    end

    def serialize_assignee(assignee, guardian: Discourse.system_user.guardian)
      base = { type: nil, user: {}, group: {} }

      case assignee
      when ::User
        base.merge(type: "user", user: serialize_user(assignee, guardian:))
      when ::Group
        base.merge(
          type: "group",
          group: serialize_record(assignee, BasicGroupSerializer, scope: Guardian.new),
        )
      else
        base
      end
    end

    def serialize_reviewable(reviewable)
      {
        id: reviewable.id,
        type: reviewable.type,
        status: reviewable.status,
        target_type: reviewable.target_type,
        target_id: reviewable.target_id,
        topic_id: reviewable.topic_id,
        category_id: reviewable.category_id,
        chat_channel_id: reviewable.try(:chat_message)&.chat_channel_id,
        score: reviewable.score,
        potential_spam: reviewable.potential_spam,
        url: "#{Discourse.base_url}/review/#{reviewable.id}",
        target_user: serialize_user(reviewable.target_user),
        created_by: serialize_user(reviewable.created_by),
        created_at: reviewable.created_at&.iso8601,
      }
    end
  end
end

# frozen_string_literal: true

module DiscourseAssign
  class McpTopicAssignments
    def self.for_topics(topics, guardian:)
      return {} if !SiteSetting.assign_enabled || topics.empty?

      unless SiteSetting.assigns_public
        guardian.preload_assign_permissions(topics.map(&:category_id))
      end
      topics = topics.select { |topic| SiteSetting.assigns_public || guardian.can_assign?(topic) }
      return {} if topics.empty?

      assignments = Assignment.active.where(topic_id: topics.map(&:id)).includes(:assigned_to).to_a
      post_ids =
        assignments.filter_map do |assignment|
          assignment.target_id if assignment.target_type == "Post"
        end
      posts =
        guardian
          .filter_visible_posts(Post.where(id: post_ids))
          .pluck(:id, :post_number, :topic_id)
          .to_h { |id, post_number, topic_id| [id, { post_number:, topic_id: }] }
      assignments_by_topic = assignments.group_by(&:topic_id)

      topics.each_with_object({}) do |topic, result|
        data = {}
        indirect = {}
        assignments_by_topic
          .fetch(topic.id, [])
          .each do |assignment|
            next if !assignment.assigned_to

            if assignment.target_type == "Topic" && assignment.target_id == topic.id
              key = assignment.assigned_to_user? ? :assigned_to_user : :assigned_to_group
              data[key] = if assignment.assigned_to_user?
                Helpers.build_assigned_to_user(assignment.assigned_to, topic)
              else
                Helpers.build_assigned_to_group(assignment.assigned_to, topic)
              end
              data[:assignment_note] = assignment.note
              data[:assignment_status] = assignment.status if SiteSetting.enable_assign_status
            elsif assignment.target_type == "Post" &&
                  posts.dig(assignment.target_id, :topic_id) == topic.id
              indirect[assignment.target_id] = {
                assigned_to: assignment.assigned_to,
                post_number: posts.fetch(assignment.target_id).fetch(:post_number),
                assignment_note: assignment.note,
                assignment_status: SiteSetting.enable_assign_status ? assignment.status : nil,
              }
            end
          end
        data[:indirectly_assigned_to] = Helpers.build_indirectly_assigned_to(
          indirect,
          topic,
        ) if indirect.present?
        result[topic.id] = data if data.present?
      end
    end
  end
end

# frozen_string_literal: true

module DiscourseAssign
  module Helpers
    def self.build_assigned_to_user(user, topic)
      return if !user
      { username: user.username, name: user.name, avatar_template: user.avatar_template }
    end

    def self.build_assigned_to_group(group, topic)
      return if !group

      {
        name: group.name,
        flair_bg_color: group.flair_bg_color,
        flair_color: group.flair_color,
        flair_icon: group.flair_icon,
        flair_upload_id: group.flair_upload_id,
      }
    end

    def self.build_indirectly_assigned_to(post_assignments, topic)
      post_assignments
        .map do |post_id, assigned_map|
          assigned_to = assigned_map[:assigned_to]
          note = assigned_map[:assignment_note]
          status = assigned_map[:assignment_status]
          post_number = assigned_map[:post_number]

          if (assigned_to.is_a?(User))
            [
              post_id,
              {
                assigned_to: build_assigned_to_user(assigned_to, topic),
                post_number: post_number,
                assignment_note: note,
                assignment_status: status,
              },
            ]
          elsif assigned_to.is_a?(Group)
            [
              post_id,
              {
                assigned_to: build_assigned_to_group(assigned_to, topic),
                post_number: post_number,
                assignment_note: note,
                assignment_status: status,
              },
            ]
          end
        end
        .to_h
    end
  end
end

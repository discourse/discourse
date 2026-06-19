# frozen_string_literal: true

module DiscourseDataExplorer
  # Deliberately minimal — exists to exercise the relationship machinery,
  # not to model User fully.
  class UserResource < ApplicationResource
    self.model = ::User
    self.type = :users

    attribute :username, :string

    filter :id # required by the belongs_to sideload from QueryResource

    # The author's own group memberships — enables the nested include `user.groups`
    # (head-to-head with the JSON:API Kit endpoint). Through the native `group_users` join, so
    # (unlike query.groups) no extra Group association patch is needed; the assign reads
    # `group.group_users` → user_id, and GroupResource exposes `filter :user_id` for it.
    many_to_many :groups,
                 resource: GroupResource,
                 foreign_key: {
                   group_users: :user_id,
                 },
                 writable: false
  end
end

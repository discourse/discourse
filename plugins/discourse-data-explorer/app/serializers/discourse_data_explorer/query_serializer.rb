# frozen_string_literal: true

module DiscourseDataExplorer
  class QuerySerializer < ActiveModel::Serializer
    attributes :id,
               :name,
               :description,
               :username,
               :group_ids,
               :last_run_at,
               :user_id,
               :is_default,
               :tags

    def username
      object&.user&.username
    end

    def group_ids
      object.groups.map(&:id)
    end

    def is_default
      object.id < 0
    end

    def tags
      object.tag_names
    end
  end
end

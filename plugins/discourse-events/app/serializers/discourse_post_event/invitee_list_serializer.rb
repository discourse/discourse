# frozen_string_literal: true

module DiscoursePostEvent
  class InviteeListSerializer < ApplicationSerializer
    root false
    attributes :meta
    has_many :invitees, serializer: InviteeSerializer, embed: :objects

    def invitees
      object[:invitees]
    end

    def meta
      {
        suggested_users:
          ActiveModel::ArraySerializer.new(
            suggested_users,
            each_serializer: BasicUserSerializer,
            scope: scope,
          ),
      }
    end

    def include_meta?
      suggested_users.present?
    end

    def suggested_users
      object[:suggested_users]
    end
  end
end

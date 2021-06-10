# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin

    attributes :user_fields

    def user_fields
      object.user_fields(@options[:user_field_ids])
    end

    def include_user_fields?
      user_fields.present?
    end
  end

  attributes :id,
             :time_read

  has_one :user, embed: :objects, serializer: UserSerializer
  attributes *DirectoryColumn.active_column_names

  def id
    object.user_id
  end

  def time_read
    object.user_stat.time_read
  end

  def include_time_read?
    object.period_type == DirectoryItem.period_types[:all]
  end
end

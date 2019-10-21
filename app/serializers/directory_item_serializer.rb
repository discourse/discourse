# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin
  end

  attributes :id,
             :time_read

  serialize_all_user_attributes = SiteSetting.respond_to?(:user_directory_includes_profile) && SiteSetting.user_directory_includes_profile

  if serialize_all_user_attributes
  class ::UserSerializer
    include UserPrimaryGroupMixin
  end

  serializer = ::UserSerializer
  else
  serializer = UserSerializer
  end

  has_one :user, embed: :objects, serializer: serializer
  attributes *DirectoryItem.headings

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

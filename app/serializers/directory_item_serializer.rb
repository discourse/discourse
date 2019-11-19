# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class DirectoryItemUserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin
  end

  attributes :id,
             :time_read,
             :user

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

  def self.user_serializer
    if SiteSetting.user_directory_includes_profile
      ::UserSerializer
    else
      DirectoryItemUserSerializer
    end
  end

  def user
    if self.class.user_serializer == ::UserSerializer
      self.class.user_serializer.new(object.user, scope: scope, root: 'user')
    else
      self.class.user_serializer.new(object.user, scope: scope, root: false)
    end
  end

end

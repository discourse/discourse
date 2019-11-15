# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
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

  def user
    if SiteSetting.user_directory_includes_profile
      ::UserSerializer.new(object.user, scope: scope, root: 'user')
    else
      UserSerializer.new(object.user, scope: scope, root: false)
    end
  end

end

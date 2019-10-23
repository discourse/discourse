# frozen_string_literal: true

class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    include UserPrimaryGroupMixin

    def attributes(*args)
      attrs = super

      if SiteSetting.respond_to?(:user_directory_includes_profile) && SiteSetting.user_directory_includes_profile
        ::UserSerializer.new(object, scope: scope).attributes.reverse_merge! attrs
      else
        attrs
      end
    end
  end

  attributes :id,
             :time_read

    has_one :user, embed: :objects, serializer: UserSerializer

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

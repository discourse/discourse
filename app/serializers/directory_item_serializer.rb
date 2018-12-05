class DirectoryItemSerializer < ApplicationSerializer

  class UserSerializer < UserNameSerializer
    attributes :primary_group_name,
               :primary_group_flair_url,
               :primary_group_flair_bg_color,
               :primary_group_flair_color

    def primary_group_name
      return nil unless object&.primary_group_id
      object&.primary_group&.name
    end

    def primary_group_flair_url
      object&.primary_group&.flair_url
    end

    def primary_group_flair_bg_color
      object&.primary_group&.flair_bg_color
    end

    def primary_group_flair_color
      object&.primary_group&.flair_color
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

class DirectoryItemSerializer < ApplicationSerializer

  attributes :id,
             :time_read

  has_one :user, embed: :objects, serializer: UserNameSerializer
  attributes *DirectoryItem.headings

  def id
    object.user_id
  end

  def time_read
    AgeWords.age_words(object.user_stat.time_read)
  end

  def include_time_read?
    object.period_type == DirectoryItem.period_types[:all]
  end

end

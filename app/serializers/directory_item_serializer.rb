class DirectoryItemSerializer < ApplicationSerializer

  attributes :id,
             :username,
             :uploaded_avatar_id,
             :avatar_template,
             :time_read

  attributes *DirectoryItem.headings

  def id
    object.user_id
  end

  def username
    object.user.username
  end

  def uploaded_avatar_id
    object.user.uploaded_avatar_id
  end

  def avatar_template
    object.user.avatar_template
  end

  def time_read
    AgeWords.age_words(object.user_stat.time_read)
  end

  def include_time_read?
    object.period_type == DirectoryItem.period_types[:all]
  end

end

require_dependency 'pinned_check'

class ListableTopicSerializer < BasicTopicSerializer

  attributes :reply_count,
             :highest_post_number,
             :image_url,
             :created_at,
             :last_posted_at,
             :bumped,
             :bumped_at,
             :unseen,
             :last_read_post_number,
             :unread,
             :new_posts,
             :pinned,
             :excerpt,
             :visible,
             :closed,
             :archived

  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects

  def bumped
    object.created_at < object.bumped_at
  end

  def seen
    return true if !scope || !scope.user
    return true if object.user_data && !object.user_data.last_read_post_number.nil?
    return true if object.created_at < scope.user.treat_as_new_topic_start_date
    false
  end

  def unseen
    !seen
  end

  def last_read_post_number
    return nil unless object.user_data
    object.user_data.last_read_post_number
  end

  def unread
    unread_helper.unread_posts
  end

  def new_posts
    unread_helper.new_posts
  end

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

  def filter(keys)
    unless object.user_data
      keys.delete(:last_read_post_number)
      keys.delete(:unread)
      keys.delete(:new_posts)
    end
    keys.delete(:excerpt) unless pinned
    keys.delete(:last_poster) unless object.include_last_poster
    super(keys)
  end

  protected

    def unread_helper
      @unread_helper ||= Unread.new(object, object.user_data)
    end

end

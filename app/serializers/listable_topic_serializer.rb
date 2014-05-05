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
             :unpinned,
             :excerpt,
             :visible,
             :closed,
             :archived

  has_one :last_poster, serializer: BasicUserSerializer, embed: :objects
  def include_last_poster?
    object.include_last_poster
  end

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

  def has_user_data
    !!object.user_data
  end

  alias :include_last_read_post_number? :has_user_data

  def unread
    unread_helper.unread_posts
  end
  alias :include_unread? :has_user_data

  def new_posts
    unread_helper.new_posts
  end
  alias :include_new_posts? :has_user_data

  def include_excerpt?
    pinned
  end

  def pinned
    PinnedCheck.pinned?(object, object.user_data)
  end

  def unpinned
    PinnedCheck.unpinned?(object, object.user_data)
  end

  protected

    def unread_helper
      @unread_helper ||= Unread.new(object, object.user_data)
    end

end

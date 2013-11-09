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
  def include_last_poster?
    object.include_last_poster
  end

  def bumped
    object.created_at < object.bumped_at
  end

  def seen
    object.user_data.present?
  end

  def unseen
    return false if scope.blank?
    return false if scope.user.blank?
    return false if object.user_data.present?
    return false if object.created_at < scope.user.treat_as_new_topic_start_date
    true
  end

  def last_read_post_number
    object.user_data.last_read_post_number
  end
  alias :include_last_read_post_number? :seen

  def unread
    unread_helper.unread_posts
  end
  alias :include_unread? :seen

  def new_posts
    unread_helper.new_posts
  end
  alias :include_new_posts? :seen

  def include_excerpt?
    pinned
  end

  def excerpt
    # excerpt should be hoisted into topic, this is an N+1 query ... yuck
    object.posts.by_post_number.first.try(:excerpt, 220, strip_links: true) || nil
  end

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

  protected

    def unread_helper
      @unread_helper ||= Unread.new(object, object.user_data)
    end

end

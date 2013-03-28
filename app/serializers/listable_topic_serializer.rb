require_dependency 'age_words'

class ListableTopicSerializer < BasicTopicSerializer

  attributes :reply_count,
             :posts_count,
             :highest_post_number,
             :image_url,
             :created_at,
             :last_posted_at,
             :bumped,
             :bumped_at,
             :bumped_age,
             :age,
             :unseen,
             :last_read_post_number,
             :unread,
             :new_posts,
             :title

  def age
    AgeWords.age_words(Time.now - (object.created_at || Time.now))
  end
  
  def bumped
    object.created_at < object.bumped_at
  end
  
  def bumped_age
    return nil if object.bumped_at.blank?
    AgeWords.age_words(Time.now - object.bumped_at)
  end
  alias include_bumped_age? :bumped

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

  protected

    def unread_helper
      @unread_helper ||= Unread.new(object, object.user_data)
    end

end

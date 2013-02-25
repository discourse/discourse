require_dependency 'age_words'

class BasicTopicSerializer < ApplicationSerializer
  include ActionView::Helpers

  attributes :id,
             :title,
             :fancy_title,
             :reply_count,
             :posts_count,
             :highest_post_number,
             :image_url,
             :created_at,
             :last_posted_at,
             :age,
             :unseen,
             :last_read_post_number,
             :unread,
             :new_posts

  def age
    AgeWords.age_words(Time.now - (object.created_at || Time.now))
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

  protected

    def unread_helper
      @unread_helper ||= Unread.new(object, object.user_data)
    end

end

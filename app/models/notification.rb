class Notification < ActiveRecord::Base
  
  belongs_to :user
  belongs_to :topic

  validates_presence_of :data
  validates_presence_of :notification_type

  def self.Types
    {:mentioned => 1,
     :replied => 2,
     :quoted => 3,
     :edited => 4,
     :liked => 5, 
     :private_message => 6,
     :invited_to_private_message => 7,
     :invitee_accepted => 8, 
     :posted => 9,
     :moved_post => 10}     
  end

  def self.InvertedTypes
    @inverted_types ||= Notification.Types.invert
  end

  def self.unread
    where(read: false)    
  end  

  def self.mark_post_read(user, topic_id, post_number)
    Notification.update_all "read = true", ["user_id = ? and topic_id = ? and post_number = ?", user.id, topic_id, post_number]
  end

  def self.recent
    order('created_at desc').limit(10)
  end

  def self.interesting_after(min_date)
    result =  where("created_at > ?", min_date)
              .includes(:topic)
              .unread
              .limit(20)
              .order("CASE WHEN notification_type = #{Notification.Types[:replied]} THEN 1
                           WHEN notification_type = #{Notification.Types[:mentioned]} THEN 2
                           ELSE 3
                      END, created_at DESC").to_a

    # Remove any duplicates by type and topic
    if result.present?
      seen = {}          
      to_remove = Set.new

      result.each do |r|
        seen[r.notification_type] ||= Set.new
        if seen[r.notification_type].include?(r.topic_id)
          to_remove << r.id 
        else
          seen[r.notification_type] << r.topic_id
        end
      end
      result.reject! {|r| to_remove.include?(r.id) }    
    end

    result
  end

  # Be wary of calling this frequently. O(n) JSON parsing can suck.
  def data_hash
    @data_hash ||= begin
      return nil if data.blank?
      ::JSON.parse(data).with_indifferent_access
    end
  end

  def text_description
    link = block_given? ? yield : ""
    I18n.t("notification_types.#{Notification.InvertedTypes[notification_type]}", data_hash.merge(link: link))
  end

  def url
    if topic.present?
      return topic.relative_url(post_number)
    end
    nil
  end

  def post
    return nil unless topic_id.present?
    return nil unless post_number.present?

    Post.where(topic_id: topic_id, post_number: post_number).first
  end

end


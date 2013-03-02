class IncomingLink < ActiveRecord::Base
  belongs_to :topic

  validates :domain, length: { in: 1..100 }
  validates :referer, length: { in: 3..1000 }
  validates :url, presence: true

  before_validation :extract_domain
  before_validation :extract_topic_and_post
  after_create :update_link_counts

  # Internal: Extract the domain from link.
  def extract_domain
    if referer.present?
      self.domain = URI.parse(referer).host
    end
  end

  # Internal: If link is internal and points to topic/post, extract their IDs.
  def extract_topic_and_post
    if url.present?
      parsed = URI.parse(url)

      begin
        params = Rails.application.routes.recognize_path(parsed.path)
        self.topic_id = params[:topic_id]
        self.post_number = params[:post_number]
      rescue ActionController::RoutingError
        # If we can't route to the url, that's OK. Don't save those two fields.
      end
    end
  end

  # Internal: Update appropriate link counts.
  def update_link_counts
    if topic_id.present?
      exec_sql("UPDATE topics
                SET incoming_link_count = incoming_link_count + 1
                WHERE id = ?", topic_id)
      if post_number.present?
        exec_sql("UPDATE posts
                  SET incoming_link_count = incoming_link_count + 1
                  WHERE topic_id = ? and post_number = ?", topic_id, post_number)
      end
    end
  end
end

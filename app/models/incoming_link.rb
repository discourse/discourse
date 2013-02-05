class IncomingLink < ActiveRecord::Base
  belongs_to :topic

  validates :domain, :length => { :in => 1..100 }
  validates :referer, :length => { :in => 3..1000 }
  validates_presence_of :url

  # Extract the domain
  before_validation do

    # Referer (remote URL)
    if referer.present?
      parsed = URI.parse(referer)
      self.domain = parsed.host
    end

    # Our URL
    if url.present?

      parsed = URI.parse(url)

      begin
        params = Rails.application.routes.recognize_path(parsed.path)
        self.topic_id = params[:topic_id] if params[:topic_id].present?
        self.post_number = params[:post_number] if params[:post_number].present?
      rescue ActionController::RoutingError
        # If we can't route to the url, that's OK. Don't save those two fields.
      end
    end

  end

  # Update appropriate incoming link counts
  after_create do
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

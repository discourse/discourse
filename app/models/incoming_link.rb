class IncomingLink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validates :url, presence: true
  validate :referer_valid

  before_validation :extract_domain
  before_validation :extract_topic_and_post
  after_create :update_link_counts

  def self.add(request,current_user=nil)
    user_id, host, referer = nil

    if request['u']
      u = User.select(:id).where(username_lower: request['u'].downcase).first
      user_id = u.id if u
    end

    if request.referer.present?
      host = URI.parse(request.referer).host
      referer = request.referer[0..999]
    end

    if host != request.host && (user_id || referer)
      cid = current_user.id if current_user
      unless cid && cid == user_id
        IncomingLink.create(url: request.url,
                            referer: referer,
                            user_id: user_id,
                            current_user_id: cid,
                            ip_address: request.remote_ip)
      end
    end

  end


  # Internal: Extract the domain from link.
  def extract_domain
    if referer.present?
      self.domain = URI.parse(self.referer).host
      self.referer = nil unless self.domain
    end
  end

  # Internal: If link is internal and points to topic/post, extract their IDs.
  def extract_topic_and_post
    if url.present?
      parsed = URI.parse(url)

      begin
        # TODO achieve same thing with no exception
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

  protected

  def referer_valid
    return true unless referer
    if (referer.length < 3 || referer.length > 100) || (domain.length < 1 || domain.length > 100)
      # internal, no need to localize
      errors.add(:referer, 'referer is invalid')
      false
    else
      true
    end
  end
end

# == Schema Information
#
# Table name: incoming_links
#
#  id              :integer          not null, primary key
#  url             :string(1000)     not null
#  referer         :string(1000)
#  domain          :string(100)
#  topic_id        :integer
#  post_number     :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer
#  ip_address      :string
#  current_user_id :integer
#
# Indexes
#
#  incoming_index                                  (topic_id,post_number)
#  index_incoming_links_on_created_at_and_domain   (created_at,domain)
#  index_incoming_links_on_created_at_and_user_id  (created_at,user_id)
#


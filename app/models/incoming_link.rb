class IncomingLink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :user

  validate :referer_valid
  validate :post_id, presence: true

  before_validation :extract_domain
  after_create :update_link_counts

  attr_accessor :url

  def self.add(opts)
    user_id, host, referer = nil
    current_user = opts[:current_user]

    if username = opts[:username]
      u = User.select(:id).find_by(username_lower: username.downcase)
      user_id = u.id if u
    end

    if opts[:referer].present?
      begin
        host = URI.parse(opts[:referer]).host
        referer = opts[:referer][0..999]
      rescue URI::InvalidURIError
        # bad uri, skip
      end
    end

    if host != opts[:host] && (user_id || referer)

      post_id = opts[:post_id]
      post_id ||= Post.where(topic_id: opts[:topic_id],
                             post_number: opts[:post_number] || 1)
                            .pluck(:id).first

      cid = current_user ? (current_user.id) : (nil)


      unless cid && cid == user_id

        IncomingLink.create(referer: referer,
                            user_id: user_id,
                            post_id: post_id,
                            current_user_id: cid,
                            ip_address: opts[:ip_address]) if post_id

      end
    end

  end


  # Internal: Extract the domain from link.
  def extract_domain
    if referer.present?
      # We may get a junk URI, just deal with it
      self.domain = URI.parse(self.referer).host rescue nil
      self.referer = nil unless self.domain
    end
  end

  # Internal: Update appropriate link counts.
  def update_link_counts
    exec_sql("UPDATE topics
              SET incoming_link_count = incoming_link_count + 1
              WHERE id = (SELECT topic_id FROM posts where id = ?)", post_id)
    exec_sql("UPDATE posts
              SET incoming_link_count = incoming_link_count + 1
              WHERE id = ?", post_id)
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
#  referer         :string(1000)
#  domain          :string(100)
#  topic_id        :integer
#  post_number     :integer
#  created_at      :datetime
#  user_id         :integer
#  ip_address      :inet
#  current_user_id :integer
#  post_id         :integer          not null
#
# Indexes
#
#  index_incoming_links_on_created_at_and_domain   (created_at,domain)
#  index_incoming_links_on_created_at_and_user_id  (created_at,user_id)
#  index_incoming_links_on_post_id                 (post_id)
#

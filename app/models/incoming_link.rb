# frozen_string_literal: true

class IncomingLink < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  belongs_to :incoming_referer

  validate :referer_valid
  validates :post_id, presence: true

  after_create :update_link_counts

  attr_accessor :url

  def self.add(opts)
    user_id, host, referer = nil
    current_user = opts[:current_user]

    username = opts[:username]
    username = nil if !(String === username)
    username = nil if username&.include?("\0")
    if username
      u = User.select(:id).find_by(username_lower: username.downcase)
      user_id = u.id if u
    end
    ip_address = opts[:ip_address]

    if opts[:referer].present?
      begin
        host = URI.parse(opts[:referer]).host
        referer = opts[:referer][0..999]
      rescue URI::Error
        # bad uri, skip
      end
    end

    if host != opts[:host] && (user_id || referer)

      post_id = opts[:post_id]
      post_id ||= Post.where(topic_id: opts[:topic_id],
                             post_number: opts[:post_number] || 1)
        .pluck(:id).first

      cid = current_user ? (current_user.id) : (nil)
      ip_address = nil if cid

      unless cid && cid == user_id

        create(referer: referer,
               user_id: user_id,
               post_id: post_id,
               current_user_id: cid,
               ip_address: ip_address) if post_id

      end
    end

  end

  def referer=(referer)
    self.incoming_referer_id = nil

    # will set incoming_referer_id
    unless referer.present?
      return
    end

    parsed = URI.parse(referer)

    if parsed.scheme == "http" || parsed.scheme == "https"
      domain = IncomingDomain.add!(parsed)

      referer_record = IncomingReferer.add!(path: parsed.path, incoming_domain: domain) if domain
      self.incoming_referer_id = referer_record.id if referer_record
    end

  rescue URI::Error
    # ignore
  end

  def referer
    if self.incoming_referer
      self.incoming_referer.incoming_domain.to_url << self.incoming_referer.path
    end
  end

  def domain
    if incoming_referer
      incoming_referer.incoming_domain.name
    end
  end

  # Internal: Update appropriate link counts.
  def update_link_counts
    DB.exec("UPDATE topics
              SET incoming_link_count = incoming_link_count + 1
              WHERE id = (SELECT topic_id FROM posts where id = ?)", post_id)
    DB.exec("UPDATE posts
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
#  id                  :integer          not null, primary key
#  created_at          :datetime         not null
#  user_id             :integer
#  ip_address          :inet
#  current_user_id     :integer
#  post_id             :integer          not null
#  incoming_referer_id :integer
#
# Indexes
#
#  index_incoming_links_on_created_at_and_user_id  (created_at,user_id)
#  index_incoming_links_on_post_id                 (post_id)
#

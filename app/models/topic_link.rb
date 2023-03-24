# frozen_string_literal: true

require "uri"

class TopicLink < ActiveRecord::Base
  def self.max_domain_length
    100
  end

  def self.max_url_length
    500
  end

  belongs_to :topic
  belongs_to :user
  belongs_to :post
  belongs_to :link_topic, class_name: "Topic"
  belongs_to :link_post, class_name: "Post"

  validates_presence_of :url

  validates_length_of :url, maximum: 500

  validates_uniqueness_of :url, scope: %i[topic_id post_id]

  has_many :topic_link_clicks, dependent: :destroy

  validate :link_to_self

  after_commit :crawl_link_title

  # Make sure a topic can't link to itself
  def link_to_self
    errors.add(:base, "can't link to the same topic") if (topic_id == link_topic_id)
  end

  def self.topic_map(guardian, topic_id)
    # Sam: complicated reports are really hard in AR
    builder = DB.build(<<~SQL)
      SELECT ftl.url,
             COALESCE(ft.title, ftl.title) AS title,
             ftl.link_topic_id,
             ftl.reflection,
             ftl.internal,
             ftl.domain,
             MIN(ftl.user_id) AS user_id,
             SUM(clicks) AS clicks
      FROM topic_links AS ftl
      LEFT JOIN topics AS ft ON ftl.link_topic_id = ft.id
      LEFT JOIN categories AS c ON c.id = ft.category_id
      /*where*/
      GROUP BY ftl.url, ft.title, ftl.title, ftl.link_topic_id, ftl.reflection, ftl.internal, ftl.domain
      ORDER BY clicks DESC, count(*) DESC
      LIMIT 50
    SQL

    builder.where("ftl.topic_id = :topic_id", topic_id: topic_id)
    builder.where("ft.deleted_at IS NULL")
    builder.where("ftl.extension IS NULL OR ftl.extension NOT IN ('png','jpg','gif')")
    builder.where(
      "COALESCE(ft.archetype, 'regular') <> :archetype",
      archetype: Archetype.private_message,
    )
    builder.where("clicks > 0")

    builder.secure_category(guardian.secure_category_ids)

    builder.query
  end

  def self.counts_for(guardian, topic, posts)
    return {} if posts.blank?

    # Sam: this is not tidy in AR and also happens to be a critical path
    # for topic view
    builder =
      DB.build(
        "SELECT
                      l.post_id,
                      l.url,
                      l.clicks,
                      COALESCE(t.title, l.title) AS title,
                      l.internal,
                      l.reflection,
                      l.domain
              FROM topic_links l
              LEFT JOIN topics t ON t.id = l.link_topic_id
              LEFT JOIN categories AS c ON c.id = t.category_id
              /*left_join*/
              /*where*/
              ORDER BY reflection ASC, clicks DESC",
      )

    builder.where("t.deleted_at IS NULL")
    builder.where(
      "COALESCE(t.archetype, 'regular') <> :archetype",
      archetype: Archetype.private_message,
    )

    if guardian.authenticated?
      builder.left_join(
        "topic_users AS tu ON (t.id = tu.topic_id AND tu.user_id = #{guardian.user.id.to_i})",
      )
      builder.where(
        "COALESCE(tu.notification_level,1) > :muted",
        muted: TopicUser.notification_levels[:muted],
      )
    end

    # not certain if pluck is right, cause it may interfere with caching
    builder.where("l.post_id in (:post_ids)", post_ids: posts.map(&:id))
    builder.secure_category(guardian.secure_category_ids)

    result = {}
    builder.query.each do |l|
      result[l.post_id] ||= []
      result[l.post_id] << {
        url: l.url,
        clicks: l.clicks,
        title: l.title,
        internal: l.internal,
        reflection: l.reflection,
      }
    end
    result
  end

  def self.extract_from(post)
    return if post.blank? || post.whisper? || post.user_id.blank? || post.deleted_at.present?

    current_urls = []
    reflected_ids = []

    PrettyText
      .extract_links(post.cooked)
      .map do |u|
        uri = UrlHelper.relaxed_parse(u.url)
        [u, uri]
      end
      .reject { |_, p| p.nil? || "mailto" == p.scheme }
      .uniq { |_, p| p }
      .each do |link, parsed|
        TopicLink.transaction do
          begin
            url, reflected_id = self.ensure_entry_for(post, link, parsed)
            current_urls << url unless url.nil?
            reflected_ids << reflected_id unless reflected_id.nil?
          rescue URI::Error
            # if the URI is invalid, don't store it.
          rescue ActionController::RoutingError
            # If we can't find the route, no big deal
          end
        end
      end

    self.cleanup_entries(post, current_urls, reflected_ids)
  end

  def self.crawl_link_title(topic_link_id)
    Jobs.enqueue(:crawl_topic_link, topic_link_id: topic_link_id)
  end

  def crawl_link_title
    TopicLink.crawl_link_title(id)
  end

  def self.duplicate_lookup(topic)
    results =
      TopicLink
        .includes(:post, :user)
        .joins(:post, :user)
        .where("posts.id IS NOT NULL AND users.id IS NOT NULL")
        .where(topic_id: topic.id, reflection: false)
        .last(200)

    lookup = {}
    results.each do |tl|
      normalized = tl.url.downcase.sub(%r{\Ahttps?://}, "").sub(%r{/\z}, "")
      lookup[normalized] = {
        domain: tl.domain,
        username: tl.user.username_lower,
        posted_at: tl.post.created_at,
        post_number: tl.post.post_number,
      }
    end

    lookup
  end

  private

  # This pattern is used to create topic links very efficiently with minimal
  # errors under heavy concurrent use
  #
  # It avoids a SELECT to find out if the record is there and minimizes all
  # the work it needs to do in case a record is missing
  #
  # It handles calling the required callback and has parity with Rails implementation
  #
  # Usually we would rely on ActiveRecord but in this case we have had lots of churn
  # around creation of topic links leading to hard to debug log messages in production
  #
  def self.safe_create_topic_link(
    post_id:,
    user_id:,
    topic_id:,
    url:,
    domain: nil,
    internal: false,
    link_topic_id: nil,
    link_post_id: nil,
    quote: false,
    extension: nil,
    reflection: false
  )
    domain ||= Discourse.current_hostname

    sql = <<~SQL
      WITH new_row AS(
        INSERT INTO topic_links(
          post_id,
          user_id,
          topic_id,
          url,
          domain,
          internal,
          link_topic_id,
          link_post_id,
          quote,
          extension,
          reflection,
          created_at,
          updated_at
        ) VALUES (
          :post_id,
          :user_id,
          :topic_id,
          :url,
          :domain,
          :internal,
          :link_topic_id,
          :link_post_id,
          :quote,
          :extension,
          :reflection,
          :now,
          :now
        )
        ON CONFLICT DO NOTHING
        RETURNING id
      )
      SELECT COALESCE(
        (SELECT id FROM new_row),
        (SELECT id FROM topic_links WHERE post_id = :post_id AND topic_id = :topic_id AND url = :url)
      ), (SELECT id FROM new_row) IS NOT NULL
    SQL

    topic_link_id, new_record =
      DB.query_single(
        sql,
        post_id: post_id,
        user_id: user_id,
        topic_id: topic_id,
        url: url,
        domain: domain,
        internal: internal,
        link_topic_id: link_topic_id,
        link_post_id: link_post_id,
        quote: quote,
        extension: extension,
        reflection: reflection,
        now: Time.now,
      )

    DB.after_commit { crawl_link_title(topic_link_id) } if new_record

    topic_link_id
  end

  def self.ensure_entry_for(post, link, parsed)
    url = link.url
    internal = false
    topic_id = nil
    post_number = nil
    topic = nil

    if upload = Upload.get_from_url(url)
      internal = Discourse.store.internal?
      # Store the same URL that will be used in the cooked version of the post
      url = UrlHelper.cook_url(upload.url, secure: upload.secure?)
    elsif route = Discourse.route_for(parsed)
      internal = true

      # We aren't interested in tracking internal links to users
      return nil if route[:controller] == "users"

      topic_id = route[:topic_id]
      topic_slug = route[:slug]
      post_number = route[:post_number] || 1

      if route[:controller] == "topics" && route[:action] == "show"
        topic_id ||= route[:id]
        topic_slug ||= route[:id]
      end

      topic = Topic.find_by(id: topic_id) if topic_id
      topic ||= Topic.find_by(slug: topic_slug) if topic_slug.present?

      if topic.present?
        url = +"#{Discourse.base_url_no_prefix}#{topic.relative_url}"
        url << "/#{post_number}" if post_number.to_i > 1
      else
        topic_id = nil
      end
    end

    # Skip linking to ourselves
    return nil if topic&.id == post.topic_id

    reflected_post = nil
    if post_number && topic
      reflected_post = Post.find_by(topic_id: topic.id, post_number: post_number.to_i)
    end

    url = url[0...TopicLink.max_url_length]
    return nil if parsed && parsed.host && parsed.host.length > TopicLink.max_domain_length

    file_extension = File.extname(parsed.path)[1..10].downcase unless parsed.path.nil? ||
      File.extname(parsed.path).empty?

    safe_create_topic_link(
      post_id: post.id,
      user_id: post.user_id,
      topic_id: post.topic_id,
      url: url,
      domain: parsed.host,
      internal: internal,
      link_topic_id: topic&.id,
      link_post_id: reflected_post&.id,
      quote: link.is_quote,
      extension: file_extension,
    )

    reflected_id = nil

    # Create the reflection if we can
    if topic && post.topic && topic.archetype != "private_message" &&
         post.topic.archetype != "private_message" && post.topic.visible?
      prefix = Discourse.base_url_no_prefix
      reflected_url = "#{prefix}#{post.topic.relative_url(post.post_number)}"

      reflected_id =
        safe_create_topic_link(
          user_id: post.user_id,
          topic_id: topic&.id,
          post_id: reflected_post&.id,
          url: reflected_url,
          domain: Discourse.current_hostname,
          reflection: true,
          internal: true,
          link_topic_id: post.topic_id,
          link_post_id: post.id,
        )
    end

    [url, reflected_id]
  end

  def self.cleanup_entries(post, current_urls, current_reflected_ids)
    # Remove links that aren't there anymore
    if current_urls.present?
      TopicLink.where(
        "(url not in (:urls)) AND (post_id = :post_id AND NOT reflection)",
        urls: current_urls,
        post_id: post.id,
      ).delete_all

      current_reflected_ids.compact!
      if current_reflected_ids.present?
        TopicLink.where(
          "(id not in (:reflected_ids)) AND (link_post_id = :post_id AND reflection)",
          reflected_ids: current_reflected_ids,
          post_id: post.id,
        ).delete_all
      else
        TopicLink.where("link_post_id = :post_id AND reflection", post_id: post.id).delete_all
      end
    else
      TopicLink.where(
        "(post_id = :post_id AND NOT reflection) OR (link_post_id = :post_id AND reflection)",
        post_id: post.id,
      ).delete_all
    end
  end
end

# == Schema Information
#
# Table name: topic_links
#
#  id            :integer          not null, primary key
#  topic_id      :integer          not null
#  post_id       :integer
#  user_id       :integer          not null
#  url           :string           not null
#  domain        :string(100)      not null
#  internal      :boolean          default(FALSE), not null
#  link_topic_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  reflection    :boolean          default(FALSE)
#  clicks        :integer          default(0), not null
#  link_post_id  :integer
#  title         :string
#  crawled_at    :datetime
#  quote         :boolean          default(FALSE), not null
#  extension     :string(10)
#
# Indexes
#
#  index_topic_links_on_extension                    (extension)
#  index_topic_links_on_link_post_id_and_reflection  (link_post_id,reflection)
#  index_topic_links_on_post_id                      (post_id)
#  index_topic_links_on_topic_id                     (topic_id)
#  index_topic_links_on_user_and_clicks              (user_id,clicks DESC,created_at DESC) WHERE ((NOT reflection) AND (NOT quote) AND (NOT internal))
#  index_topic_links_on_user_id                      (user_id)
#  unique_post_links                                 (topic_id,post_id,url) UNIQUE
#

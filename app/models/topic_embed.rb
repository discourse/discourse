# frozen_string_literal: true

class TopicEmbed < ActiveRecord::Base
  include Trashable

  EMBED_CONTENT_CACHE_MAX_LENGTH = 32_000

  belongs_to :topic
  belongs_to :post
  validates_presence_of :embed_url
  validates_uniqueness_of :embed_url
  validates :embed_content_cache, length: { maximum: EMBED_CONTENT_CACHE_MAX_LENGTH }

  before_validation(on: :create) do
    unless (
             topic_embed =
               TopicEmbed
                 .with_deleted
                 .where("deleted_at IS NOT NULL AND embed_url = ?", embed_url)
                 .first
           ).nil?
      topic_embed.destroy!
    end
  end

  class FetchResponse
    attr_accessor :title, :body, :author, :url
  end

  def self.normalize_url(url)
    # downcase
    # remove trailing forward slash/
    # remove consecutive hyphens
    # remove leading and trailing whitespace
    url.downcase.sub(%r{/\z}, "").sub(/\-+/, "-").strip
  end

  def self.imported_from_html(url)
    url = UrlHelper.normalized_encode(url)
    I18n.with_locale(SiteSetting.default_locale) do
      "\n<hr>\n<small>#{I18n.t("embed.imported_from", link: "<a href='#{url}'>#{url}</a>")}</small>\n"
    end
  end

  # Import an article from a source (RSS/Atom/Other)
  def self.import(user, url, title, contents, category_id: nil, cook_method: nil, tags: nil)
    return unless url =~ %r{\Ahttps?\://}

    original_contents = contents.dup.truncate(EMBED_CONTENT_CACHE_MAX_LENGTH)
    contents = first_paragraph_from(contents) if SiteSetting.embed_truncate && cook_method.nil?
    contents ||= ""
    contents = contents.dup << imported_from_html(url)

    url = normalize_url(url)

    embed = topic_embed_by_url(url)
    content_sha1 = Digest::SHA1.hexdigest(contents)
    post = nil

    # If there is no embed, create a topic, post and the embed.
    if embed.blank?
      Topic.transaction do
        if eh = EmbeddableHost.record_for_url(url)
          tags = eh.tags.presence&.map(&:name) || tags
          user = eh.user.presence || user
        end

        cook_method ||=
          if SiteSetting.embed_support_markdown
            Post.cook_methods[:regular]
          else
            Post.cook_methods[:raw_html]
          end

        create_args = {
          title: title,
          raw: absolutize_urls(url, contents),
          skip_validations: true,
          cook_method: cook_method,
          category: category_id || eh.try(:category_id),
          tags: SiteSetting.tagging_enabled ? tags : nil,
          embed_url: url,
          embed_content_sha1: content_sha1,
        }
        create_args[:visible] = false if SiteSetting.import_embed_unlisted?

        # always return `args` when using this modifier, e.g:
        #
        # plugin.register_modifier(:topic_embed_import_create_args) do |args|
        #   args[:title] = "MODIFIED: #{args[:title]}"
        #
        #   args # returning args is important to prevent errors
        # end
        create_args =
          DiscoursePluginRegistry.apply_modifier(:topic_embed_import_create_args, create_args) ||
            create_args

        post = PostCreator.create(user, create_args)
        post.topic.topic_embed.update!(embed_content_cache: original_contents)
      end
    else
      absolutize_urls(url, contents)
      post = embed.post

      if eh = EmbeddableHost.record_for_url(url)
        tags = eh.tags.presence || tags
        user = eh.user.presence || user
      end

      # Update the topic if it changed
      if post&.topic
        if post.user != user
          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: post.topic_id,
            new_owner: user,
            acting_user: Discourse.system_user,
          ).change_owner!

          # make sure the post returned has the right author
          post.reload
        end

        existing_tag_names = post.topic.tags.pluck(:name).sort
        incoming_tag_names = Array(tags).map { |tag| tag.respond_to?(:name) ? tag.name : tag }.sort

        tags_changed = !tags.nil? && existing_tag_names != incoming_tag_names

        if (content_sha1 != embed.content_sha1) || (title && title != post&.topic&.title) ||
             tags_changed
          changes = { raw: absolutize_urls(url, contents) }

          changes[:tags] = incoming_tag_names if SiteSetting.tagging_enabled && tags_changed
          changes[:title] = title if title.present?

          post.revise(user, changes, skip_validations: true, bypass_rate_limiter: true)
          embed.update!(content_sha1: content_sha1, embed_content_cache: original_contents)
        end
      end
    end

    post
  end

  def self.find_remote(url)
    url = UrlHelper.normalized_encode(url)
    URI.parse(url) # ensure url parses, will raise if not
    fd = FinalDestination.new(url, validate_uri: true, max_redirects: 5, follow_canonical: true)

    uri = fd.resolve
    return if uri.blank?

    begin
      html = FinalDestination::HTTP.get(uri)
    rescue OpenURI::HTTPError, Net::OpenTimeout, FinalDestination::SSRFDetector::DisallowedIpError
      return
    end

    parse_html(html, uri.to_s)
  end

  def self.parse_html(html, url)
    require "ruby-readability"

    opts = {
      tags: %w[
        div
        p
        code
        pre
        h1
        h2
        h3
        b
        em
        i
        strong
        a
        img
        ul
        li
        ol
        blockquote
        figure
        figcaption
        details
      ],
      attributes: %w[href src class],
      remove_empty_nodes: false,
      elements_to_score: %w[p],
    }

    opts[
      :whitelist
    ] = SiteSetting.allowed_embed_selectors if SiteSetting.allowed_embed_selectors.present?
    opts[
      :blacklist
    ] = SiteSetting.blocked_embed_selectors if SiteSetting.blocked_embed_selectors.present?
    allowed_embed_classnames =
      SiteSetting.allowed_embed_classnames if SiteSetting.allowed_embed_classnames.present?

    response = FetchResponse.new

    raw_doc = Nokogiri.HTML5(html)

    response.url = url

    auth_element =
      raw_doc.at('meta[@name="discourse-username"]') || raw_doc.at('meta[@name="author"]')
    if auth_element.present?
      response.author = User.where(username_lower: auth_element[:content].strip).first
    end

    read_doc = Readability::Document.new(html, opts)

    title = +(raw_doc.title || "")
    title.strip!

    if SiteSetting.embed_title_scrubber.present?
      title.sub!(Regexp.new(SiteSetting.embed_title_scrubber), "")
      title.strip!
    end
    response.title = title
    doc = Nokogiri.HTML5(read_doc.content)

    tags = { "img" => "src", "script" => "src", "a" => "href" }
    doc
      .search(tags.keys.join(","))
      .each do |node|
        url_param = tags[node.name]
        src = node[url_param]
        unless (src.nil? || src.empty?)
          begin
            # convert URL to absolute form
            node[url_param] = URI.join(url, UrlHelper.normalized_encode(src)).to_s
          rescue URI::Error, Addressable::URI::InvalidURIError
            # If there is a mistyped URL, just do nothing
          end
        end
        # only allow classes in the allowlist
        allowed_classes =
          if allowed_embed_classnames.blank?
            []
          else
            allowed_embed_classnames.split(/[ ,]+/i)
          end
        doc
          .search('[class]:not([class=""])')
          .each do |classnode|
            classes =
              classnode[:class]
                .split(" ")
                .select { |classname| allowed_classes.include?(classname) }
            if classes.length === 0
              classnode.delete("class")
            else
              classnode[:class] = classes.join(" ")
            end
          end
      end

    response.body = doc.at("body").children.to_html
    response
  end

  def self.import_remote(url, opts = nil)
    opts = opts || {}
    response = find_remote(url)
    return if response.nil?

    response.title = opts[:title] if opts[:title].present?
    import_user = opts[:user] if opts[:user].present?
    import_user = response.author if response.author.present?
    url = normalize_url(response.url) if response.url.present?

    TopicEmbed.import(import_user, url, response.title, response.body)
  end

  # Convert any relative URLs to absolute. RSS is annoying for this.
  def self.absolutize_urls(url, contents)
    url = normalize_url(url)
    begin
      uri = URI(UrlHelper.normalized_encode(url))
    rescue URI::Error
      return contents
    end
    prefix = "#{uri.scheme}://#{uri.host}"
    prefix += ":#{uri.port}" if uri.port != 80 && uri.port != 443

    fragment = Nokogiri::HTML5.fragment("<div>#{contents}</div>")
    fragment
      .css("a")
      .each do |a|
        if a["href"].present?
          begin
            a["href"] = URI.join(prefix, a["href"]).to_s
          rescue URI::InvalidURIError
            # NOOP, URL is malformed
          end
        end
      end

    fragment
      .css("img")
      .each do |a|
        if a["src"].present?
          begin
            a["src"] = URI.join(prefix, a["src"]).to_s
          rescue URI::InvalidURIError
            # NOOP, URL is malformed
          end
        end
      end

    fragment.at("div").inner_html
  end

  def self.topic_embed_by_url(embed_url)
    embed_url = normalize_url(embed_url).sub(%r{\Ahttps?\://}, "")
    TopicEmbed.where("embed_url ~* ?", "^https?://#{Regexp.escape(embed_url)}$").first
  end

  def self.topic_id_for_embed(embed_url)
    topic_embed = topic_embed_by_url(embed_url)
    topic_embed&.topic_id
  end

  def self.first_paragraph_from(html)
    doc = Nokogiri.HTML5(html)

    result = +""
    doc
      .css("p")
      .each do |p|
        if p.text.present?
          result << p.to_s
          return result if result.size >= 100
        end
      end
    return result if result.present?

    # If there is no first paragraph, return the first div (onebox)
    doc.css("div").first.to_s
  end

  def self.expanded_for(post)
    Discourse
      .cache
      .fetch("embed-topic:#{post.topic_id}", expires_in: 10.minutes) do
        url = TopicEmbed.where(topic_id: post.topic_id).pick(:embed_url)
        response = TopicEmbed.find_remote(url)

        body = response.body
        if post&.topic&.topic_embed && body.present?
          post.topic.topic_embed.update!(
            embed_content_cache: body.truncate(EMBED_CONTENT_CACHE_MAX_LENGTH),
          )
        end
        body << TopicEmbed.imported_from_html(url)
        body
      end
  end
end

# == Schema Information
#
# Table name: topic_embeds
#
#  id                  :integer          not null, primary key
#  topic_id            :integer          not null
#  post_id             :integer          not null
#  embed_url           :string(1000)     not null
#  content_sha1        :string(40)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  deleted_at          :datetime
#  deleted_by_id       :integer
#  embed_content_cache :text
#
# Indexes
#
#  index_topic_embeds_on_embed_url  (embed_url) UNIQUE
#

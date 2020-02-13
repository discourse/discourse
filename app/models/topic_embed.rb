# frozen_string_literal: true

class TopicEmbed < ActiveRecord::Base
  include Trashable

  belongs_to :topic
  belongs_to :post
  validates_presence_of :embed_url
  validates_uniqueness_of :embed_url

  before_validation(on: :create) do
    unless (topic_embed = TopicEmbed.with_deleted.where('deleted_at IS NOT NULL AND embed_url = ?', embed_url).first).nil?
      topic_embed.destroy!
    end
  end

  class FetchResponse
    attr_accessor :title, :body, :author
  end

  def self.normalize_url(url)
    url.downcase.sub(/\/$/, '').sub(/\-+/, '-').strip
  end

  def self.imported_from_html(url)
    "\n<hr>\n<small>#{I18n.t('embed.imported_from', link: "<a href='#{url}'>#{url}</a>")}</small>\n"
  end

  # Import an article from a source (RSS/Atom/Other)
  def self.import(user, url, title, contents)
    return unless url =~ /^https?\:\/\//

    if SiteSetting.embed_truncate
      contents = first_paragraph_from(contents)
    end
    contents ||= ''
    contents = +contents << imported_from_html(url)

    url = normalize_url(url)

    embed = TopicEmbed.find_by("lower(embed_url) = ?", url)
    content_sha1 = Digest::SHA1.hexdigest(contents)
    post = nil

    # If there is no embed, create a topic, post and the embed.
    if embed.blank?
      Topic.transaction do
        eh = EmbeddableHost.record_for_url(url)

        cook_method = if SiteSetting.embed_support_markdown
          Post.cook_methods[:regular]
        else
          Post.cook_methods[:raw_html]
        end

        creator = PostCreator.new(user,
                                  title: title,
                                  raw: absolutize_urls(url, contents),
                                  skip_validations: true,
                                  cook_method: cook_method,
                                  category: eh.try(:category_id))
        post = creator.create
        if post.present?
          TopicEmbed.create!(topic_id: post.topic_id,
                             embed_url: url,
                             content_sha1: content_sha1,
                             post_id: post.id)
        end
      end
    else
      absolutize_urls(url, contents)
      post = embed.post

      # Update the topic if it changed
      if post&.topic
        if post.user != user
          PostOwnerChanger.new(
            post_ids: [post.id],
            topic_id: post.topic_id,
            new_owner: user,
            acting_user: Discourse.system_user
          ).change_owner!

          # make sure the post returned has the right author
          post.reload
        end

        if content_sha1 != embed.content_sha1
          post.revise(
            user,
            { raw: absolutize_urls(url, contents) },
            skip_validations: true,
            bypass_rate_limiter: true
          )
          embed.update!(content_sha1: content_sha1)
        end
      end
    end

    post
  end

  def self.find_remote(url)
    require 'ruby-readability'

    url = UrlHelper.escape_uri(url)
    original_uri = URI.parse(url)
    opts = {
      tags: %w[div p code pre h1 h2 h3 b em i strong a img ul li ol blockquote],
      attributes: %w[href src class],
      remove_empty_nodes: false
    }

    opts[:whitelist] = SiteSetting.embed_whitelist_selector if SiteSetting.embed_whitelist_selector.present?
    opts[:blacklist] = SiteSetting.embed_blacklist_selector if SiteSetting.embed_blacklist_selector.present?
    embed_classname_whitelist = SiteSetting.embed_classname_whitelist if SiteSetting.embed_classname_whitelist.present?

    response = FetchResponse.new
    begin
      html = open(url, allow_redirections: :safe).read
    rescue OpenURI::HTTPError, Net::OpenTimeout
      return
    end

    raw_doc = Nokogiri::HTML(html)
    auth_element = raw_doc.at('meta[@name="author"]')
    if auth_element.present?
      response.author = User.where(username_lower: auth_element[:content].strip).first
    end

    read_doc = Readability::Document.new(html, opts)

    title = +(raw_doc.title || '')
    title.strip!

    if SiteSetting.embed_title_scrubber.present?
      title.sub!(Regexp.new(SiteSetting.embed_title_scrubber), '')
      title.strip!
    end
    response.title = title
    doc = Nokogiri::HTML(read_doc.content)

    tags = { 'img' => 'src', 'script' => 'src', 'a' => 'href' }
    doc.search(tags.keys.join(',')).each do |node|
      url_param = tags[node.name]
      src = node[url_param]
      unless (src.nil? || src.empty?)
        begin
          uri = URI.parse(UrlHelper.escape_uri(src))
          unless uri.host
            uri.scheme = original_uri.scheme
            uri.host = original_uri.host
            node[url_param] = uri.to_s
          end
        rescue URI::Error
          # If there is a mistyped URL, just do nothing
        end
      end
      # only allow classes in the whitelist
      allowed_classes = if embed_classname_whitelist.blank? then [] else embed_classname_whitelist.split(/[ ,]+/i) end
      doc.search('[class]:not([class=""])').each do |classnode|
        classes = classnode[:class].split(' ').select { |classname| allowed_classes.include?(classname) }
        if classes.length === 0
          classnode.delete('class')
        else
          classnode[:class] = classes.join(' ')
        end
      end
    end

    response.body = doc.to_html
    response
  end

  def self.import_remote(import_user, url, opts = nil)
    opts = opts || {}
    response = find_remote(url)
    return if response.nil?

    response.title = opts[:title] if opts[:title].present?
    import_user = response.author if response.author.present?

    TopicEmbed.import(import_user, url, response.title, response.body)
  end

  # Convert any relative URLs to absolute. RSS is annoying for this.
  def self.absolutize_urls(url, contents)
    url = normalize_url(url)
    begin
      uri = URI(UrlHelper.escape_uri(url))
    rescue URI::Error
      return contents
    end
    prefix = "#{uri.scheme}://#{uri.host}"
    prefix << ":#{uri.port}" if uri.port != 80 && uri.port != 443

    fragment = Nokogiri::HTML.fragment("<div>#{contents}</div>")
    fragment.css('a').each do |a|
      href = a['href']
      if href.present? && href.start_with?('/')
        a['href'] = "#{prefix}/#{href.sub(/^\/+/, '')}"
      end
    end
    fragment.css('img').each do |a|
      src = a['src']
      if src.present? && src.start_with?('/')
        a['src'] = "#{prefix}/#{src.sub(/^\/+/, '')}"
      end
    end
    fragment.at('div').inner_html
  end

  def self.topic_id_for_embed(embed_url)
    embed_url = normalize_url(embed_url).sub(/^https?\:\/\//, '')
    TopicEmbed.where("embed_url ~* ?", "^https?://#{Regexp.escape(embed_url)}$").pluck_first(:topic_id)
  end

  def self.first_paragraph_from(html)
    doc = Nokogiri::HTML(html)

    result = +""
    doc.css('p').each do |p|
      if p.text.present?
        result << p.to_s
        return result if result.size >= 100
      end
    end
    return result unless result.blank?

    # If there is no first paragaph, return the first div (onebox)
    doc.css('div').first.to_s
  end

  def self.expanded_for(post)
    Discourse.cache.fetch("embed-topic:#{post.topic_id}", expires_in: 10.minutes) do
      url = TopicEmbed.where(topic_id: post.topic_id).pluck_first(:embed_url)
      response = TopicEmbed.find_remote(url)

      body = response.body
      body << TopicEmbed.imported_from_html(url)
      body
    end
  end

end

# == Schema Information
#
# Table name: topic_embeds
#
#  id            :integer          not null, primary key
#  topic_id      :integer          not null
#  post_id       :integer          not null
#  embed_url     :string(1000)     not null
#  content_sha1  :string(40)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  deleted_at    :datetime
#  deleted_by_id :integer
#
# Indexes
#
#  index_topic_embeds_on_embed_url  (embed_url) UNIQUE
#

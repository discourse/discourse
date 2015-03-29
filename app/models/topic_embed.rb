require_dependency 'nokogiri'

class TopicEmbed < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  validates_presence_of :embed_url

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
    contents << imported_from_html(url)

    url = normalize_url(url)

    embed = TopicEmbed.find_by("lower(embed_url) = ?", url)
    content_sha1 = Digest::SHA1.hexdigest(contents)
    post = nil

    # If there is no embed, create a topic, post and the embed.
    if embed.blank?
      Topic.transaction do
        creator = PostCreator.new(user,
                                  title: title,
                                  raw: absolutize_urls(url, contents),
                                  skip_validations: true,
                                  cook_method: Post.cook_methods[:raw_html],
                                  category: SiteSetting.embed_category)
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
      if post && post.topic && content_sha1 != embed.content_sha1
        post.revise(user, { raw: absolutize_urls(url, contents) }, skip_validations: true, bypass_rate_limiter: true)
        embed.update_column(:content_sha1, content_sha1)
      end
    end

    post
  end

  def self.find_remote(url)
    require 'ruby-readability'

    url = normalize_url(url)
    original_uri = URI.parse(url)
    opts = {
      tags: %w[div p code pre h1 h2 h3 b em i strong a img ul li ol blockquote],
      attributes: %w[href src],
      remove_empty_nodes: false
    }

    opts[:whitelist] = SiteSetting.embed_whitelist_selector if SiteSetting.embed_whitelist_selector.present?
    opts[:blacklist] = SiteSetting.embed_blacklist_selector if SiteSetting.embed_blacklist_selector.present?

    doc = Readability::Document.new(open(url).read, opts)

    tags = {'img' => 'src', 'script' => 'src', 'a' => 'href'}
    title = doc.title
    doc = Nokogiri::HTML(doc.content)
    doc.search(tags.keys.join(',')).each do |node|
      url_param = tags[node.name]
      src = node[url_param]
      unless (src.empty?)
        begin
          uri = URI.parse(src)
          unless uri.host
            uri.scheme = original_uri.scheme
            uri.host = original_uri.host
            node[url_param] = uri.to_s
          end
        rescue URI::InvalidURIError
          # If there is a mistyped URL, just do nothing
        end
      end
    end

    [title, doc.to_html]
  end

  def self.import_remote(user, url, opts=nil)
    opts = opts || {}
    title, body = find_remote(url)
    TopicEmbed.import(user, url, opts[:title] || title, body)
  end

  # Convert any relative URLs to absolute. RSS is annoying for this.
  def self.absolutize_urls(url, contents)
    url = normalize_url(url)
    uri = URI(url)
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
    embed_url = normalize_url(embed_url)
    TopicEmbed.where("lower(embed_url) = ?", embed_url).pluck(:topic_id).first
  end

  def self.first_paragraph_from(html)
    doc = Nokogiri::HTML(html)

    result = ""
    doc.css('p').each do |p|
      if p.text.present?
        result << p.to_s
        return result if result.size >= 100
      end
    end
    return result unless result.blank?

    # If there is no first paragaph, return the first div (onebox)
    doc.css('div').first
  end

  def self.expanded_for(post)
    Rails.cache.fetch("embed-topic:#{post.topic_id}", expires_in: 10.minutes) do
      url = TopicEmbed.where(topic_id: post.topic_id).pluck(:embed_url).first
      _title, body = TopicEmbed.find_remote(url)
      body << TopicEmbed.imported_from_html(url)
      body
    end
  end

end

# == Schema Information
#
# Table name: topic_embeds
#
#  id           :integer          not null, primary key
#  topic_id     :integer          not null
#  post_id      :integer          not null
#  embed_url    :string(255)      not null
#  content_sha1 :string(40)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_topic_embeds_on_embed_url  (embed_url) UNIQUE
#

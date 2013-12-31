require_dependency 'nokogiri'

class TopicEmbed < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  validates_presence_of :embed_url
  validates_presence_of :content_sha1

  # Import an article from a source (RSS/Atom/Other)
  def self.import(user, url, title, contents)
    return unless url =~ /^https?\:\/\//

    contents << "\n<hr>\n<small>#{I18n.t('embed.imported_from', link: "<a href='#{url}'>#{url}</a>")}</small>\n"

    embed = TopicEmbed.where(embed_url: url).first
    content_sha1 = Digest::SHA1.hexdigest(contents)
    post = nil

    # If there is no embed, create a topic, post and the embed.
    if embed.blank?
      Topic.transaction do
        creator = PostCreator.new(user, title: title, raw: absolutize_urls(url, contents), skip_validations: true, cook_method: Post.cook_methods[:raw_html])
        post = creator.create
        if post.present?
          TopicEmbed.create!(topic_id: post.topic_id,
                             embed_url: url,
                             content_sha1: content_sha1,
                             post_id: post.id)
        end
      end
    else
      post = embed.post
      # Update the topic if it changed
      if content_sha1 != embed.content_sha1
        revisor = PostRevisor.new(post)
        revisor.revise!(user, absolutize_urls(url, contents), skip_validations: true, bypass_rate_limiter: true)
        embed.update_column(:content_sha1, content_sha1)
      end
    end

    post
  end

  def self.import_remote(user, url, opts=nil)
    require 'ruby-readability'

    opts = opts || {}
    doc = Readability::Document.new(open(url).read,
                                        tags: %w[div p code pre h1 h2 h3 b em i strong a img],
                                        attributes: %w[href src])

    TopicEmbed.import(user, url, opts[:title] || doc.title, doc.content)
  end

  # Convert any relative URLs to absolute. RSS is annoying for this.
  def self.absolutize_urls(url, contents)
    uri = URI(url)
    prefix = "#{uri.scheme}://#{uri.host}"
    prefix << ":#{uri.port}" if uri.port != 80 && uri.port != 443

    fragment = Nokogiri::HTML.fragment(contents)
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

    fragment.to_html
  end

  def self.topic_id_for_embed(embed_url)
    TopicEmbed.where(embed_url: embed_url).pluck(:topic_id).first
  end

end

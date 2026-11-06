# frozen_string_literal: true

xml.instruct!
xml.rss(version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom") do
  xml.channel do
    xml.title SiteSetting.blog_title
    xml.link blog_url("/")
    xml.description SiteSetting.blog_description
    xml.tag!("atom:link", href: blog_url("/feed.xml"), rel: "self", type: "application/rss+xml")
    @publications.each do |publication|
      xml.item do
        xml.title publication.article.title
        xml.link publication.url
        xml.guid "#{Discourse.base_url}/blog/publications/#{publication.topic_id}", isPermaLink: "false"
        xml.pubDate publication.published_at.rfc2822
        xml.description blog_article_html(publication.article)
        xml.comments publication.discussion_topic.url
      end
    end
  end
end

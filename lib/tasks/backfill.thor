class Backfill < Thor
  desc "link_titles", "Backfills link titles"

  def link_titles
    require './config/environment'
    topic_links = TopicLink.where(crawled_at: nil, internal: false)

    puts "Enqueueing Topic Links: #{topic_links.count} links found."

    topic_links.pluck(:id).each do |tl|
      Jobs.enqueue(:crawl_topic_link, topic_link_id: tl)
    end
  end
end

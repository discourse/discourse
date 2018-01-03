module ListHelper
  def page_links(topic)
    posts = topic.posts_count
    max_pages = 10
    total_pages = (posts / TopicView.chunk_size) + (posts == TopicView.chunk_size ? 0 : 1)

    return if total_pages < 2

    page = [total_pages - (max_pages + 1), 2].max

    result = "("
    while page <= total_pages
      result << " <a href='#{topic.relative_url}?page=#{page}'>#{page}</a> "
      page += 1
    end

    result << ")"
    result.html_safe
  end
end

module ListsHelper
  def render_list_next_page_link(list,topics_length)
    if topics_length > 0
      link_to("next page", list.more_topics_url.sub(".json?","?") )
    end
  end
end
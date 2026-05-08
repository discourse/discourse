# frozen_string_literal: true

class PostExcerptAccordionItemSerializer < BasicPostSerializer
  attributes :post_number, :topic_id, :url

  def url
    object&.url
  end
end

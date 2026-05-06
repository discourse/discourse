# frozen_string_literal: true

class PostExcerptAccordionItemSerializer < BasicPostSerializer
  attributes :post_number,
             :topic_id,
             :post_url,
             def post_url
               object&.url
             end
end

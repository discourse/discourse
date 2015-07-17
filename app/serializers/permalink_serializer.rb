class PermalinkSerializer < ApplicationSerializer
  attributes :id, :url, :topic_id, :post_id, :category_id, :external_url
end

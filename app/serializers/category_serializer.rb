class CategorySerializer < ApplicationSerializer

  attributes :id,
             :name,
             :color,
             :slug,
             :topic_count,
             :description,
             :topic_url

end

# frozen_string_literal: true

Fabricator(:topic_embed) do
  post
  embed_url "http://eviltrout.com/123"
  topic { |te| te[:post].topic }
end

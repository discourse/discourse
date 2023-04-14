# frozen_string_literal: true

Fabricator(:topic_embed) do
  post
  topic { |te| te[:post].topic }
end

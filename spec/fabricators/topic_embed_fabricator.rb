Fabricator(:topic_embed) do
  post
  topic { |te| te[:post].topic }
end

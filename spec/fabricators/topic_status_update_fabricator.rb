Fabricator(:topic_status_update) do
  user
  topic
  execute_at Time.zone.now + 1.hour
  status_type TopicStatusUpdate.types[:close]
end

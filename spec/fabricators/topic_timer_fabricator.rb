Fabricator(:topic_timer) do
  user
  topic
  execute_at Time.zone.now + 1.hour
  status_type TopicTimer.types[:close]
end

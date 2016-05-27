class TopicTag < ActiveRecord::Base
  belongs_to :topic
  belongs_to :tag, counter_cache: "topic_count"
end

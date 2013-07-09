# The most basic attributes of a topic that we need to create a link for it.
class BasicTopicSerializer < ApplicationSerializer
  attributes :id, :title, :fancy_title, :slug, :posts_count
end

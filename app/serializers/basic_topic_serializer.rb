# frozen_string_literal: true

# The most basic attributes of a topic that we need to create a link for it.
class BasicTopicSerializer < ApplicationSerializer
  root 'basic_topic'
  attributes :id, :title, :fancy_title, :slug, :posts_count
end

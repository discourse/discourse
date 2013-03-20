require_dependency 'age_words'

# The most basic attributes of a topic that we need to create a link for it.
class BasicTopicSerializer < ApplicationSerializer
  attributes :id, :fancy_title, :slug
end

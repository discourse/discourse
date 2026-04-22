# frozen_string_literal: true

module TopicVotingCategory
  include ::RSpec::Matchers

  def votes
    ".nav-item_votes.votes"
  end

  def select_topic(topic)
    find("tr[data-topic-id=\"#{topic.id}\"] a.raw-link").click
  end
end

PageObjects::Pages::Category.include(TopicVotingCategory)

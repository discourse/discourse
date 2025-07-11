# frozen_string_literal: true

module TopicVotingTopic
  include ::RSpec::Matchers

  def vote_count
    find(".voting .vote-count")
  end

  def vote_popup
    find(".voting-popup-menu")
  end

  def vote
    find("button.vote-button").click
    self
  end

  def remove_vote
    vote
    find(".remove-vote").click
    self
  end

  def click_vote_popup_activity
    find(".voting-popup-menu a").click
  end
end

PageObjects::Pages::Topic.include(TopicVotingTopic)

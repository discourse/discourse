# frozen_string_literal: true

module TopicVotingTopic
  include ::RSpec::Matchers

  def vote_count
    find(".title-voting .voting-wrapper__count-text")
  end

  def vote_popup
    find(".see-votes")
  end

  def vote
    find(".title-voting button.voting-wrapper__button").click
    self
  end

  def remove_vote
    if SiteSetting.topic_voting_enable_vote_limits
      vote
      find("button.remove-vote").click
    else
      find(".title-voting button.voting-wrapper__button").click
    end
    self
  end

  def click_my_votes
    find(".see-votes").click
  end

  def has_no_remove_vote_button?
    has_no_css?("button.remove-vote")
  end

  def has_voted?
    has_css?(".title-voting button.voting-wrapper__button.btn-success")
  end

  def has_not_voted?
    has_css?(".title-voting button.voting-wrapper__button.btn-default") &&
      has_no_css?(".title-voting button.voting-wrapper__button.btn-success")
  end
end

PageObjects::Pages::Topic.include(TopicVotingTopic)

# frozen_string_literal: true

module TopicVotingTopic
  include ::RSpec::Matchers

  def vote_count
    find(".voting .vote-count")
  end

  def has_locked_popup?
    expected_html = I18n.t("js.topic_voting.locked_description")
    selector = ".topic-voting-menu__title.--locked"
    has_css?(selector)
    actual_html = find(selector)[:innerHTML].strip
    actual_html.include?(expected_html)
  end

  def vote_popup
    find(".topic-voting-menu__votes-left")
  end

  def vote
    find("button.vote-button").click
    self
  end

  def remove_vote
    vote
    find("button.remove-vote").click
    self
  end

  def click_my_votes
    find(".topic-voting-menu__votes-left").click
  end
end

PageObjects::Pages::Topic.include(TopicVotingTopic)

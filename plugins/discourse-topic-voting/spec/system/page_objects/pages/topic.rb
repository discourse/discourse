# frozen_string_literal: true

module TopicVotingTopic
  include ::RSpec::Matchers

  def vote_count
    find(".voting .vote-count")
  end

  def has_votes_left_popup?(count)
    expected_html =
      I18n
        .t("js.topic_voting.votes_left", count:, path: "/my/activity/votes")
        .gsub(/'([^']*)'/) { "\"#{$1}\"" }
    selector = ".topic-voting-menu__row-title"
    has_css?(selector)
    actual_html = find(selector)[:innerHTML].strip
    actual_html.include?(expected_html)
  end

  def has_locked_popup?
    expected_html = I18n.t("js.topic_voting.locked_description")
    selector = ".topic-voting-menu__title.--locked"
    has_css?(selector)
    actual_html = find(selector)[:innerHTML].strip
    actual_html.include?(expected_html)
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

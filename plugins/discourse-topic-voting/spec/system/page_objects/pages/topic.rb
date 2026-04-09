# frozen_string_literal: true

module TopicVotingTopic
  include ::RSpec::Matchers

  def vote_count
    find(".title-voting .vote-count")
  end

  def has_locked_popup?
    expected_html = I18n.t("js.topic_voting.locked_description")
    selector = ".topic-voting-menu__title.--locked"
    has_css?(selector)
    actual_html = find(selector)[:innerHTML].strip
    actual_html.include?(expected_html)
  end

  def vote_popup
    find(".see-votes")
  end

  def vote
    find(".title-voting button.vote-button").click
    self
  end

  def remove_vote
    if SiteSetting.topic_voting_enable_vote_limits
      vote
      find("button.remove-vote").click
    else
      find(".title-voting button.vote-button").click
    end
    self
  end

  def click_my_votes
    find(".see-votes").click
  end

  def has_vote_button_label?(text)
    has_css?(".title-voting button.vote-button[aria-label='#{text}']")
  end

  def has_no_remove_vote_button?
    has_no_css?("button.remove-vote")
  end

  def has_see_all_votes_link?
    has_css?(".see-votes", text: I18n.t("js.topic_voting.see_all_votes"))
  end

  def has_no_votes_left_text?
    has_no_css?(".see-votes", text: %r{\d+/\d+})
  end

  def has_voted?
    has_css?(".title-voting button.vote-button.btn-success")
  end

  def has_not_voted?
    has_css?(".title-voting button.vote-button.btn-default") &&
      has_no_css?(".title-voting button.vote-button.btn-success")
  end
end

PageObjects::Pages::Topic.include(TopicVotingTopic)

# frozen_string_literal: true

module TopicVotingCategory
  include ::RSpec::Matchers

  def votes
    ".nav-item_votes.votes"
  end

  def topic_with_vote_count(vote_count)
    "tr.topic-list-item a.list-vote-count.vote-count-#{vote_count}"
  end

  def select_topic(topic)
    if SiteSetting.topic_voting_show_vote_in_topic_list
      find("tr[data-topic-id=\"#{topic.id}\"] a.raw-link").click
    else
      find("tr[data-topic-id=\"#{topic.id}\"] a.list-vote-count.vote-count-0").click
    end
  end
end

PageObjects::Pages::Category.include(TopicVotingCategory)

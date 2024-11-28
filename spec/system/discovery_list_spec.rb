# frozen_string_literal: true

describe "Discovery list", type: :system do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:reply) { Fabricate(:post, topic: topics.first) }

  let(:discovery) { PageObjects::Pages::Discovery.new }

  def nth_topic_id(n)
    discovery.topic_list.find(".topic-list-item:nth-of-type(#{n})")["data-topic-id"]
  end

  it "can sort a topic list by activity" do
    visit "/latest"
    expect(discovery.topic_list).to have_topics(count: 10)
    newest_topic_id = nth_topic_id(1)

    find("th[data-sort-order='activity']").click

    expect(page).to have_css("th[data-sort-order='activity'][aria-sort=ascending]")
    expect(nth_topic_id(10)).to eq(newest_topic_id)

    find("th[data-sort-order='activity']").click
    expect(page).to have_css("th[data-sort-order='activity'][aria-sort=descending]")
    expect(nth_topic_id(1)).to eq(newest_topic_id)
  end

  it "can sort a topic list by replies" do
    visit "/latest"
    expect(discovery.topic_list).to have_topics(count: 10)

    find("th[data-sort-order='posts']").click

    expect(page).to have_css("th[data-sort-order='posts'][aria-sort=descending]")
    expect(nth_topic_id(1)).to eq(reply.topic_id.to_s)

    find("th[data-sort-order='posts']").click
    expect(page).to have_css("th[data-sort-order='posts'][aria-sort=ascending]")
    expect(nth_topic_id(10)).to eq(reply.topic_id.to_s)
  end

  describe "bulk topic options" do
    fab!(:user)
    fab!(:topic) { Fabricate(:topic, user: user) }
    fab!(:post1) { create_post(user: user, topic: topic) }
    fab!(:post2) { create_post(topic: topic) }

    it "should correctly show/hide the bulk select toggle for regular users" do
      sign_in(user)
      visit("/unread")

      # The bulk select toggle should be visible, the user has an unread post
      find("button.bulk-select").click
      expect(page).to have_css(".topic-list-body .bulk-select")

      find("#navigation-bar .latest > a").click

      # No bulk select toggle, no actions available in /latest
      expect(page).to have_no_css(".topic-list-body .bulk-select")
    end
  end
end

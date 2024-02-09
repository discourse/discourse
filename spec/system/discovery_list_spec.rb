# frozen_string_literal: true

describe "Topic list focus", type: :system do
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
end

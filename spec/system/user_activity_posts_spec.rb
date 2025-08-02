# frozen_string_literal: true

describe "User activity posts", type: :system do
  before_all { UserActionManager.enable }
  fab!(:user)

  fab!(:topic1) do
    Fabricate(:topic, title: "Title with &amp; characters and emoji :wave:").tap do |t|
      Fabricate.times(2, :post, topic: t, user:).each { |p| UserActionManager.post_created(p) }
    end
  end
  fab!(:topic2) do
    Fabricate(:topic).tap do |t|
      Fabricate.times(2, :post, topic: t, user:).each { |p| UserActionManager.post_created(p) }
    end
  end

  it "lists posts with correctly-formatted titles" do
    visit "/u/#{user.username_lower}/activity/replies"

    expect(page).to have_css(".stream-topic-title .title", count: 2)

    title_element = find(".stream-topic-title .title a[href*='/#{topic1.id}/']")
    expect(title_element).to have_text("Title with &amp; characters and emoji")
    expect(title_element).to have_css("img.emoji[title='wave']")
  end
end

# frozen_string_literal: true

describe "Discovery heading accessibility", type: :system do
  let(:discovery) { PageObjects::Pages::Discovery.new }

  fab!(:category) { Fabricate(:category, name: "General") }
  fab!(:tag) { Fabricate(:tag, name: "help") }

  fab!(:topic_in_category) { Fabricate(:topic, category: category) }
  fab!(:topic_with_tag) { Fabricate(:topic, tags: [tag]) }
  fab!(:topic_in_category_tagged) { Fabricate(:topic, category: category, tags: [tag]) }

  it "shows correct heading for category view" do
    visit "/c/#{category.slug}/#{category.id}"
    expect(page).to have_selector("h1", text: "latest topics in General")
  end

  it "shows correct heading for tagged view" do
    visit "/tags/#{tag.name}"
    expect(page).to have_selector("h1", text: "latest topics tagged help")
  end

  it "shows correct heading for category + tag view" do
    visit "/tags/c/#{category.slug}/#{category.id}/#{tag.name}"
    expect(page).to have_selector("h1", text: "latest topics in General tagged help")
  end

  it "shows correct heading for no tags view" do
    visit "/tags/none"
    expect(page).to have_selector("h1", text: "all topics without tags")
  end

  it "shows default heading for latest topics" do
    visit "/latest"
    expect(page).to have_selector("h1", text: "all latest topics")
  end

  it "shows heading for all categories view" do
    visit "/categories"
    expect(page).to have_selector("h1", text: "all categories")
  end

  it "shows heading for bookmarked topics" do
    user = sign_in(Fabricate(:user))
    topic = Fabricate(:topic)
    Fabricate(:bookmark, user: user, topic: topic)

    visit "/bookmarks"
    expect(page).to have_selector("h1", text: "all topics you’ve bookmarked")
  end

  it "shows heading for posted topics" do
    user = sign_in(Fabricate(:user))
    topic = Fabricate(:topic)
    Fabricate(:post, topic: topic, user: user)

    visit "/posted"
    expect(page).to have_selector("h1", text: "all topics you’ve posted in")
  end
end

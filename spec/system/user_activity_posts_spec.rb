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

  context "when tagging enabled" do
    fab!(:tag1) { Fabricate(:tag, name: "js", staff_topic_count: 2, public_topic_count: 1) }
    fab!(:tag2) { Fabricate(:tag, name: "css", staff_topic_count: 1, public_topic_count: 2) }

    before do
      SiteSetting.tagging_enabled = true
      topic1.tags = [tag1, tag2]
    end

    it "displays tags in correct order for regular users" do
      visit "/u/#{user.username_lower}/activity"

      expect(page.all(".discourse-tag").map(&:text)).to eq(%w[css js])
    end

    context "when user is staff" do
      before { user.update!(admin: true) }

      it "displays tags in staff order" do
        sign_in(user)
        visit "my/activity"

        expect(page.all(".discourse-tag").map(&:text)).to eq(%w[js css])
      end
    end
  end

  context "when tagging disabled" do
    before { SiteSetting.tagging_enabled = false }

    it "does not display tags" do
      visit "/u/#{user.username_lower}/activity"

      expect(page).to have_no_css(".discourse-tags")
    end
  end
end

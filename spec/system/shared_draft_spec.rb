# frozen_string_literal: true

describe "Shared drafts" do
  let(:parent_category) { Fabricate(:category, slug: "foo") }
  let(:child_category) { Fabricate(:category, parent_category: parent_category, slug: "bar") }
  let!(:shared_draft_topic) do
    SiteSetting.shared_drafts_category = child_category.id
    topic = Fabricate(:topic, category: child_category)
    Fabricate(:post, topic: topic)
    shared_draft = Fabricate(:shared_draft, category: parent_category, topic: topic)
    topic
  end

  it "shared draft has class for current category" do
    sign_in Fabricate(:admin)

    visit "/t/#{shared_draft_topic.id}"
    expect(page).to have_css("body.category-foo-bar")
  end

  it "lazy-load-categories - shared draft has class for current category" do
    SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}"

    sign_in Fabricate(:admin)
    visit "/t/#{shared_draft_topic.id}"
    expect(page).to have_css("body.category-foo-bar")
  end
end

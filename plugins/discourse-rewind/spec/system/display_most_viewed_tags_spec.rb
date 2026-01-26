# frozen_string_literal: true

describe "Display most viewed tags in rewind", type: :system do
  fab!(:current_user) { Fabricate(:user, created_at: DateTime.parse("2020-01-01")) }
  fab!(:tag_1, :tag)
  fab!(:tag_2, :tag)
  fab!(:tag_3, :tag)
  fab!(:topic_1) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_2) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_3) { Fabricate(:topic, tags: [tag_2]) }
  fab!(:topic_4) { Fabricate(:topic, tags: [tag_3]) }
  fab!(:topic_view_1) do
    TopicViewItem.create!(
      topic_id: topic_1.id,
      user_id: current_user.id,
      viewed_at: Date.new(2022, 3, 15),
      ip_address: "127.0.0.1",
    )
  end
  fab!(:topic_view_2) do
    TopicViewItem.create!(
      topic_id: topic_2.id,
      user_id: current_user.id,
      viewed_at: Date.new(2022, 4, 20),
      ip_address: "127.0.0.2",
    )
  end
  fab!(:topic_view_3) do
    TopicViewItem.create!(
      topic_id: topic_3.id,
      user_id: current_user.id,
      viewed_at: Date.new(2022, 5, 10),
      ip_address: "127.0.0.3",
    )
  end
  fab!(:topic_view_4) do
    TopicViewItem.create!(
      topic_id: topic_4.id,
      user_id: current_user.id,
      viewed_at: Date.new(2022, 6, 5),
      ip_address: "127.0.0.4",
    )
  end

  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    SiteSetting.tagging_enabled = true

    sign_in(current_user)
  end

  it "displays most viewed tags with correct names and links" do
    freeze_time DateTime.parse("2022-12-05")

    rewind_page.visit_rewind(current_user.username)

    expect(rewind_page).to have_rewind_loaded
    expect(rewind_page).to have_most_viewed_tags_report
    expect(rewind_page).to have_tag_in_report(tag_1)
    expect(rewind_page).to have_tag_in_report(tag_2)
    expect(rewind_page).to have_tag_in_report(tag_3)
  end
end

# frozen_string_literal: true

describe "Display most viewed tags in rewind", type: :system do
  fab!(:current_user) do
    Fabricate(
      :user,
      refresh_auto_groups: true,
      trust_level: 2,
      created_at: DateTime.parse("2020-01-01"),
    )
  end
  fab!(:tag_1) { Fabricate(:tag, name: "ruby") }
  fab!(:tag_2) { Fabricate(:tag, name: "javascript") }
  fab!(:tag_3) { Fabricate(:tag, name: "python") }
  fab!(:topic_1) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_2) { Fabricate(:topic, tags: [tag_1]) }
  fab!(:topic_3) { Fabricate(:topic, tags: [tag_2]) }
  fab!(:topic_4) { Fabricate(:topic, tags: [tag_3]) }

  let(:rewind_page) { PageObjects::Pages::Rewind.new }

  before do
    SiteSetting.discourse_rewind_enabled = true
    SiteSetting.tagging_enabled = true

    sign_in(current_user)
    freeze_time DateTime.parse("2022-12-05")

    TopicViewItem.add(topic_1.id, "127.0.0.1", current_user.id, Date.new(2022, 3, 15))
    TopicViewItem.add(topic_2.id, "127.0.0.2", current_user.id, Date.new(2022, 4, 20))
    TopicViewItem.add(topic_3.id, "127.0.0.3", current_user.id, Date.new(2022, 5, 10))
    TopicViewItem.add(topic_4.id, "127.0.0.4", current_user.id, Date.new(2022, 6, 5))
  end

  it "displays most viewed tags with correct names and links" do
    rewind_page.visit_rewind(current_user.username)

    expect(rewind_page).to have_rewind_loaded
    expect(rewind_page).to have_most_viewed_tags_report
    expect(rewind_page).to have_tag_in_report(tag_1)
    expect(rewind_page).to have_tag_in_report(tag_2)
    expect(rewind_page).to have_tag_in_report(tag_3)
    expect(rewind_page).to have_tag_link(tag_1)
    expect(rewind_page).to have_tag_link(tag_2)
    expect(rewind_page).to have_tag_link(tag_3)
  end
end

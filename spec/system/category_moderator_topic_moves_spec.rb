# frozen_string_literal: true

describe "Category moderator topic moves" do
  fab!(:moderator) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:destination) do
    Fabricate(:private_category, group:, permission_type: CategoryGroup.permission_types[:readonly])
  end
  fab!(:post) { Fabricate(:post, user: moderator) }

  it "includes a moderated read-only category when moving an existing topic" do
    group.add(moderator)
    Fabricate(:category_moderation_group, category: destination, group:)
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.category_group_moderators_can_move_topics = true
    sign_in(moderator)
    topic = post.topic
    topic_page = PageObjects::Pages::Topic.new
    category_chooser =
      PageObjects::Components::SelectKit.new(".edit-category__wrapper .category-chooser")

    topic_page.visit_topic(topic)
    topic_page.click_topic_edit_title
    category_chooser.expand
    category_chooser.select_row_by_value(destination.id)
    topic_page.click_topic_title_submit_edit

    expect(topic_page).to have_no_css("#topic-title .submit-edit")
    expect(topic.reload.category).to eq(destination)
  end
end

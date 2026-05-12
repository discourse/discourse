# frozen_string_literal: true

describe "Bulk convert PMs to public topics" do
  fab!(:admin)
  fab!(:category)
  fab!(:pm) { Fabricate(:private_message_topic, recipient: admin) }
  fab!(:pm_post) { Fabricate(:post, topic: pm, user: pm.user) }

  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:modal) { PageObjects::Modals::TopicBulkActions.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(admin) }

  it "silently moves selected PMs into the chosen category" do
    visit("/u/#{admin.username}/messages")

    topic_list_header.click_bulk_select_button
    topic_list.click_topic_checkbox(pm)
    topic_list_header.click_bulk_select_topics_dropdown
    topic_list_header.click_bulk_button("convert-to-public-topic")

    modal.category_selector.expand
    modal.category_selector.select_row_by_value(category.id)
    modal.click_bulk_topics_confirm

    expect(toasts).to have_success(I18n.t("js.topics.bulk.completed"))
    expect(pm.reload.archetype).to eq(Archetype.default)
    expect(pm.category_id).to eq(category.id)
    expect(pm.posts.where(post_type: Post.types[:small_action])).to be_empty
  end
end

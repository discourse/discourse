# frozen_string_literal: true

describe "Bulk pin and unpin topics" do
  fab!(:admin)
  fab!(:category)
  fab!(:topic_1) { Fabricate(:topic, category: category) }
  fab!(:topic_2) { Fabricate(:topic, category: category) }
  fab!(:post_1) { Fabricate(:post, topic: topic_1) }
  fab!(:post_2) { Fabricate(:post, topic: topic_2) }

  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_bulk_actions_modal) { PageObjects::Modals::TopicBulkActions.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(admin) }

  it "allows a user to pin and unpin multiple topics in bulk" do
    visit("/latest")

    expect(topic_list).to have_no_pinned_status(topic_1)
    expect(topic_list).to have_no_pinned_status(topic_2)

    topic_list_header.click_bulk_select_button
    topic_list.click_topic_checkbox(topic_1)
    topic_list.click_topic_checkbox(topic_2)
    topic_list_header.click_bulk_select_topics_dropdown
    topic_list_header.click_bulk_button("pin-topics")

    topic_bulk_actions_modal.pin_in_category_date_selector.expand
    topic_bulk_actions_modal.pin_in_category_date_selector.select_row_by_value("next_month")
    topic_bulk_actions_modal.click_pin_in_category

    expect(toasts).to have_success(I18n.t("js.topics.bulk.completed"))

    visit("/latest")

    expect(topic_list).to have_pinned_status(topic_1)
    expect(topic_list).to have_pinned_status(topic_2)

    topic_list_header.click_bulk_select_button
    topic_list.click_topic_checkbox(topic_1)
    topic_list.click_topic_checkbox(topic_2)
    topic_list_header.click_bulk_select_topics_dropdown
    topic_list_header.click_bulk_button("unpin-topics")

    topic_bulk_actions_modal.click_bulk_topics_confirm

    expect(toasts).to have_success(I18n.t("js.topics.bulk.completed"))

    visit("/latest")

    expect(topic_list).to have_no_pinned_status(topic_1)
    expect(topic_list).to have_no_pinned_status(topic_2)
  end

  it "displays pin counts and confirms before pinning globally when many are already pinned" do
    topic_1.update_pinned(true, false)

    4.times do
      t = Fabricate(:topic)
      Fabricate(:post, topic: t)
      t.update_pinned(true, true)
    end

    dialog = PageObjects::Components::Dialog.new

    visit("/c/#{category.id}")

    topic_list_header.click_bulk_select_button
    topic_list.click_topic_checkbox(topic_2)
    topic_list_header.click_bulk_select_topics_dropdown
    topic_list_header.click_bulk_button("pin-topics")

    expect(topic_bulk_actions_modal).to have_pin_stats_text(
      "Topics currently pinned in #{category.name} : 1",
    )
    expect(topic_bulk_actions_modal).to have_pin_stats_text("Topics currently pinned globally: 4")

    topic_bulk_actions_modal.pin_globally_date_selector.expand
    topic_bulk_actions_modal.pin_globally_date_selector.select_row_by_value("next_month")
    topic_bulk_actions_modal.click_pin_globally

    expect(dialog).to have_content(I18n.t("js.topic.feature_topic.confirm_pin_globally", count: 4))
    dialog.click_yes

    expect(toasts).to have_success(I18n.t("js.topics.bulk.completed"))
  end
end

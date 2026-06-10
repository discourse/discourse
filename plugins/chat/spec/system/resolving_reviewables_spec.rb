# frozen_string_literal: true

describe "Resolving chat message reviewables from the review queue" do
  fab!(:admin)
  fab!(:performing_moderator, :moderator)
  fab!(:channel, :chat_channel)

  fab!(:kept_message) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:deleted_message) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:disagreed_message) { Fabricate(:chat_message, chat_channel: channel) }
  fab!(:ignored_message) { Fabricate(:chat_message, chat_channel: channel) }

  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    chat_system_bootstrap(admin, [channel])
    sign_in(admin)
    Jobs.run_immediately!
  end

  it "shows each resolved reviewable's status in both open queues" do
    review_queue = Chat::ReviewQueue.new
    spam_flag = ReviewableScore.types[:spam]
    kept_message_reviewable =
      review_queue.flag_message(kept_message, admin.guardian, spam_flag).fetch(:reviewable)
    deleted_message_reviewable =
      review_queue.flag_message(deleted_message, admin.guardian, spam_flag).fetch(:reviewable)
    disagreed_message_reviewable =
      review_queue.flag_message(disagreed_message, admin.guardian, spam_flag).fetch(:reviewable)
    ignored_message_reviewable =
      review_queue.flag_message(ignored_message, admin.guardian, spam_flag).fetch(:reviewable)

    using_session(:other_tab) do
      sign_in(performing_moderator)
      visit("/review")

      expect(review_page).to have_reviewables(
        [
          kept_message_reviewable,
          deleted_message_reviewable,
          disagreed_message_reviewable,
          ignored_message_reviewable,
        ],
      )
    end

    visit("/review")

    expect(review_page).to have_reviewables(
      [
        kept_message_reviewable,
        deleted_message_reviewable,
        disagreed_message_reviewable,
        ignored_message_reviewable,
      ],
    )

    review_page.select_bundled_action(
      kept_message_reviewable,
      "chat_message-agree_and_keep_message",
      bundle_index: 1,
    )

    expect(review_page).to have_reviewable_with_approved_status(kept_message_reviewable)

    review_page.select_bundled_action(
      deleted_message_reviewable,
      "chat_message-agree_and_delete",
      bundle_index: 1,
    )

    expect(review_page).to have_reviewable_with_approved_status(deleted_message_reviewable)

    review_page.select_bundled_action(
      disagreed_message_reviewable,
      "chat_message-disagree",
      bundle_index: 2,
    )

    expect(review_page).to have_reviewable_with_rejected_status(disagreed_message_reviewable)

    review_page.select_bundled_action(
      ignored_message_reviewable,
      "chat_message-ignore",
      bundle_index: 2,
    )

    expect(review_page).to have_reviewable_with_ignored_status(ignored_message_reviewable)
    expect(review_page).to have_reviewables(
      [
        kept_message_reviewable,
        deleted_message_reviewable,
        disagreed_message_reviewable,
        ignored_message_reviewable,
      ],
    )

    using_session(:other_tab) do
      expect(review_page).to have_reviewable_with_approved_status(kept_message_reviewable)
      expect(review_page).to have_reviewable_with_approved_status(deleted_message_reviewable)
      expect(review_page).to have_reviewable_with_rejected_status(disagreed_message_reviewable)
      expect(review_page).to have_reviewable_with_ignored_status(ignored_message_reviewable)
      expect(review_page).to have_reviewables(
        [
          kept_message_reviewable,
          deleted_message_reviewable,
          disagreed_message_reviewable,
          ignored_message_reviewable,
        ],
      )
    end
  end
end

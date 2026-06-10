# frozen_string_literal: true

describe "Resolving AI reviewables from the review queue" do
  fab!(:admin)
  fab!(:watching_admin, :admin)

  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    enable_current_plugin
    sign_in(admin)
    Jobs.run_immediately!
  end

  context "with AI post reviewables" do
    fab!(:agreed_reviewable) do
      ReviewableAiPost.needs_review!(target: Fabricate(:post), created_by: Discourse.system_user)
    end

    fab!(:disagreed_reviewable) do
      ReviewableAiPost.needs_review!(target: Fabricate(:post), created_by: Discourse.system_user)
    end

    fab!(:ignored_reviewable) do
      ReviewableAiPost.needs_review!(target: Fabricate(:post), created_by: Discourse.system_user)
    end

    fab!(:deleted_reviewable) do
      ReviewableAiPost.needs_review!(target: Fabricate(:post), created_by: Discourse.system_user)
    end

    it "shows each resolved reviewable's status in both open queues" do
      using_session(:other_tab) do
        sign_in(watching_admin)
        visit("/review")

        expect(review_page).to have_reviewables(
          [agreed_reviewable, disagreed_reviewable, ignored_reviewable, deleted_reviewable],
        )
      end

      visit("/review")

      expect(review_page).to have_reviewables(
        [agreed_reviewable, disagreed_reviewable, ignored_reviewable, deleted_reviewable],
      )

      review_page.select_bundled_action(agreed_reviewable, "post-agree_and_keep", bundle_index: 1)

      expect(review_page).to have_reviewable_with_approved_status(agreed_reviewable)

      review_page.select_bundled_action(disagreed_reviewable, "post-disagree", bundle_index: 2)

      expect(review_page).to have_reviewable_with_rejected_status(disagreed_reviewable)

      review_page.select_bundled_action(ignored_reviewable, "post-ignore", bundle_index: 2)

      expect(review_page).to have_reviewable_with_ignored_status(ignored_reviewable)

      review_page.select_bundled_action(
        deleted_reviewable,
        "post-delete_and_agree",
        bundle_index: 1,
      )

      expect(review_page).to have_reviewable_with_approved_status(deleted_reviewable)
      expect(review_page).to have_reviewables(
        [agreed_reviewable, disagreed_reviewable, ignored_reviewable, deleted_reviewable],
      )

      using_session(:other_tab) do
        expect(review_page).to have_reviewable_with_approved_status(agreed_reviewable)
        expect(review_page).to have_reviewable_with_rejected_status(disagreed_reviewable)
        expect(review_page).to have_reviewable_with_ignored_status(ignored_reviewable)
        expect(review_page).to have_reviewable_with_approved_status(deleted_reviewable)
        expect(review_page).to have_reviewables(
          [agreed_reviewable, disagreed_reviewable, ignored_reviewable, deleted_reviewable],
        )
      end
    end
  end

  context "with AI chat message reviewables" do
    fab!(:kept_message_reviewable) do
      ReviewableAiChatMessage.needs_review!(
        target: Fabricate(:chat_message),
        created_by: Discourse.system_user,
      )
    end

    fab!(:deleted_message_reviewable) do
      ReviewableAiChatMessage.needs_review!(
        target: Fabricate(:chat_message),
        created_by: Discourse.system_user,
      )
    end

    fab!(:disagreed_message_reviewable) do
      ReviewableAiChatMessage.needs_review!(
        target: Fabricate(:chat_message),
        created_by: Discourse.system_user,
      )
    end

    fab!(:ignored_message_reviewable) do
      ReviewableAiChatMessage.needs_review!(
        target: Fabricate(:chat_message),
        created_by: Discourse.system_user,
      )
    end

    before { SiteSetting.chat_enabled = true }

    it "shows each resolved reviewable's status in both open queues" do
      using_session(:other_tab) do
        sign_in(watching_admin)
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

  context "with AI tool action reviewables" do
    fab!(:ai_agent)

    fab!(:approved_reviewable) do
      tool_action =
        AiToolAction.create!(
          tool_name: "close_topic",
          tool_parameters: {
            topic_id: Fabricate(:topic).id,
            closed: true,
            reason: "Off-topic",
          },
          ai_agent: ai_agent,
          bot_user_id: Discourse.system_user.id,
        )

      reviewable =
        ReviewableAiToolAction.needs_review!(
          target: tool_action,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
          payload: {
            agent_name: ai_agent.name,
            reason: "Off-topic",
          },
        )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        force_review: true,
      )
      reviewable
    end

    fab!(:rejected_reviewable) do
      tool_action =
        AiToolAction.create!(
          tool_name: "close_topic",
          tool_parameters: {
            topic_id: Fabricate(:topic).id,
            closed: true,
            reason: "Off-topic",
          },
          ai_agent: ai_agent,
          bot_user_id: Discourse.system_user.id,
        )

      reviewable =
        ReviewableAiToolAction.needs_review!(
          target: tool_action,
          created_by: Discourse.system_user,
          reviewable_by_moderator: true,
          payload: {
            agent_name: ai_agent.name,
            reason: "Off-topic",
          },
        )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:needs_approval],
        force_review: true,
      )
      reviewable
    end

    before { SiteSetting.ai_bot_enabled = true }

    it "shows each resolved reviewable's status in both open queues" do
      using_session(:other_tab) do
        sign_in(watching_admin)
        visit("/review")

        expect(review_page).to have_reviewables([approved_reviewable, rejected_reviewable])
      end

      visit("/review")

      expect(review_page).to have_reviewables([approved_reviewable, rejected_reviewable])

      review_page.select_action(approved_reviewable, "ai_tool_action-approve")

      expect(review_page).to have_reviewable_with_approved_status(approved_reviewable)

      review_page.select_action(rejected_reviewable, "ai_tool_action-reject")

      expect(review_page).to have_reviewable_with_rejected_status(rejected_reviewable)
      expect(review_page).to have_reviewables([approved_reviewable, rejected_reviewable])

      using_session(:other_tab) do
        expect(review_page).to have_reviewable_with_approved_status(approved_reviewable)
        expect(review_page).to have_reviewable_with_rejected_status(rejected_reviewable)
        expect(review_page).to have_reviewables([approved_reviewable, rejected_reviewable])
      end
    end
  end
end

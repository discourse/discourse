# frozen_string_literal: true

RSpec.describe ReviewableAiToolAction do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:topic)

  let(:bot_user) { Discourse.system_user }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  def create_tool_action(tool_name: "close_topic", params: nil, post_id: nil)
    params ||= { topic_id: topic.id, closed: true, reason: "Off-topic" }
    AiToolAction.create!(
      tool_name: tool_name,
      tool_parameters: params,
      ai_agent: ai_agent,
      bot_user_id: bot_user.id,
      post_id: post_id,
    )
  end

  def create_reviewable(tool_action)
    reviewable =
      described_class.needs_review!(
        target: tool_action,
        created_by: bot_user,
        reviewable_by_moderator: true,
        payload: {
          agent_name: "Test Agent",
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

  describe "#perform" do
    it "records access restrictions from approved category changes and post moves" do
      SiteSetting.dsa_reporting_enabled = true
      private_category = Fabricate(:private_category, group: Group[:staff])
      author = Fabricate(:user)
      post = Fabricate(:post, topic: topic, user: author)
      category_reviewable =
        create_reviewable(
          create_tool_action(
            tool_name: "change_topic_category",
            params: {
              topic_id: topic.id,
              category_id: private_category.id,
              reason: "Privacy",
            },
          ),
        )

      category_reviewable.perform(admin, :approve)

      expect(author.guardian.can_see_post?(post.reload)).to eq(false)
      expect(
        DsaStatementOfRecord.where(reviewable_id: category_reviewable.id).sole.payload[
          "decision_visibility"
        ],
      ).to eq(["DECISION_VISIBILITY_CONTENT_DISABLED"])

      public_post = Fabricate(:post)
      reply = Fabricate(:post, topic: public_post.topic, user: author, post_number: 2)
      move_reviewable =
        create_reviewable(
          create_tool_action(
            tool_name: "move_posts",
            params: {
              topic_id: public_post.topic_id,
              post_ids: [reply.id],
              destination_topic_id: topic.id,
              reason: "Privacy",
            },
          ),
        )

      move_reviewable.perform(admin, :approve)

      expect(author.guardian.can_see_post?(reply.reload)).to eq(false)
      expect(
        DsaStatementOfRecord.where(reviewable_id: move_reviewable.id).sole.payload[
          "decision_visibility"
        ],
      ).to eq(["DECISION_VISIBILITY_CONTENT_DISABLED"])
    end

    it "records no access restriction when approved moves preserve public access" do
      SiteSetting.dsa_reporting_enabled = true
      post = Fabricate(:post, topic: topic)
      category = Fabricate(:category)
      reviewable =
        create_reviewable(
          create_tool_action(
            tool_name: "change_topic_category",
            params: {
              topic_id: topic.id,
              category_id: category.id,
              reason: "Organisation",
            },
          ),
        )

      reviewable.perform(admin, :approve)

      expect(post.user.guardian.can_see_post?(post.reload)).to eq(true)
      expect(DsaStatementOfRecord.where(reviewable_id: reviewable.id)).to be_empty

      reply = Fabricate(:post, topic: topic, post_number: 2)
      destination = Fabricate(:post)
      move_reviewable =
        create_reviewable(
          create_tool_action(
            tool_name: "move_posts",
            params: {
              topic_id: topic.id,
              post_ids: [reply.id],
              destination_topic_id: destination.topic_id,
              reason: "Organisation",
            },
          ),
        )

      move_reviewable.perform(admin, :approve)

      expect(reply.user.guardian.can_see_post?(reply.reload)).to eq(true)
      expect(DsaStatementOfRecord.where(reviewable_id: move_reviewable.id)).to be_empty
    end

    it "records topic interaction and visibility restrictions applied by an approved tool" do
      SiteSetting.dsa_reporting_enabled = true
      post = Fabricate(:post, topic: topic)
      reviewable = create_reviewable(create_tool_action)

      reviewable.perform(admin, :approve)

      statement = DsaStatementOfRecord.where(reviewable_id: reviewable.id).sole
      expect(statement.payload).to include(
        "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"],
        "content_type" => ["CONTENT_TYPE_TEXT"],
        "content_date" => post.created_at.to_date.iso8601,
        "automated_detection" => "No",
        "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
      )
      unlist_reviewable =
        create_reviewable(
          create_tool_action(
            tool_name: "unlist_topic",
            params: {
              topic_id: topic.id,
              unlisted: true,
              reason: "Off-topic",
            },
          ),
        )
      unlist_reviewable.perform(admin, :approve)
      expect(
        DsaStatementOfRecord.where(reviewable_id: unlist_reviewable.id).sole.payload[
          "decision_visibility"
        ],
      ).to eq(["DECISION_VISIBILITY_CONTENT_DEMOTED"])
      {
        "lock_post" => {
          post_id: post.id,
          locked: true,
          reason: "Disruptive edits",
        },
        "set_slow_mode" => {
          topic_id: topic.id,
          slow_mode_seconds: 60,
          reason: "Disruptive replies",
        },
      }.each do |name, params|
        restriction_reviewable =
          create_reviewable(create_tool_action(tool_name: name, params: params))

        restriction_reviewable.perform(admin, :approve)

        expect(
          DsaStatementOfRecord.where(reviewable_id: restriction_reviewable.id).sole.payload[
            "decision_visibility"
          ],
        ).to eq(["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"])
      end
      rejected = create_reviewable(create_tool_action)
      rejected.perform(admin, :reject)
      expect(DsaStatementOfRecord.where(reviewable_id: rejected.id)).to be_empty
    end
  end

  describe "#created_new!" do
    fab!(:private_category_group, :group)
    fab!(:private_category) { Fabricate(:private_category, group: private_category_group) }
    fab!(:private_topic) { Fabricate(:topic, category: private_category) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic) }

    it "scopes the reviewable to the target post's topic and category" do
      tool_action = create_tool_action(post_id: private_post.id)
      reviewable = create_reviewable(tool_action)

      expect(reviewable.topic).to eq(private_topic)
      expect(reviewable.category).to eq(private_category)
    end

    it "leaves topic and category blank when the target action has no post" do
      tool_action = create_tool_action(post_id: nil)
      reviewable = create_reviewable(tool_action)

      expect(reviewable.topic).to be_nil
      expect(reviewable.category).to be_nil
    end
  end

  describe "#build_actions" do
    it "has approve and reject actions when pending" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      actions = Reviewable::Actions.new(reviewable, Guardian.new(admin), {})
      reviewable.build_actions(actions, Guardian.new(admin), {})

      expect(actions.has?(:approve)).to eq(true)
      expect(actions.has?(:reject)).to eq(true)
    end

    it "returns no actions when not pending" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      reviewable.status = Reviewable.statuses[:approved]

      actions = Reviewable::Actions.new(reviewable, Guardian.new(admin), {})
      reviewable.build_actions(actions, Guardian.new(admin), {})

      expect(actions.has?(:approve)).to eq(false)
      expect(actions.has?(:reject)).to eq(false)
    end

    it "returns no actions for a user who cannot see the review queue" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      regular_user = Fabricate(:user)

      actions = Reviewable::Actions.new(reviewable, Guardian.new(regular_user), {})
      reviewable.build_actions(actions, Guardian.new(regular_user), {})

      expect(actions.has?(:approve)).to eq(false)
      expect(actions.has?(:reject)).to eq(false)
    end

    it "returns actions for a category group moderator scoped to the reviewable's category" do
      category = Fabricate(:category)
      post = Fabricate(:post, topic: Fabricate(:topic, category: category))
      tool_action = create_tool_action(post_id: post.id)
      reviewable = create_reviewable(tool_action)

      SiteSetting.enable_category_group_moderation = true
      group = Fabricate(:group)
      Fabricate(:category_moderation_group, category:, group:)
      group_moderator = Fabricate(:user, groups: [group])

      actions = Reviewable::Actions.new(reviewable, Guardian.new(group_moderator), {})
      reviewable.build_actions(actions, Guardian.new(group_moderator), {})

      expect(actions.has?(:approve)).to eq(true)
      expect(actions.has?(:reject)).to eq(true)
    end
  end

  describe "#perform_approve" do
    it "executes the tool and transitions to approved" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:approved)
      expect(topic.reload.closed).to eq(true)
    end

    it "executes inline approval from the bot post containing its approval card" do
      source_post = Fabricate(:post, topic: topic)
      tool_action = create_tool_action(post_id: source_post.id)
      reviewable = create_reviewable(tool_action)
      approval_post =
        Fabricate(
          :post,
          topic: topic,
          user: bot_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      result = nil
      expect { result = reviewable.perform(admin, :approve, post_id: approval_post.id) }.to change {
        Jobs::ResumeAiToolApproval.jobs.size
      }.by(1)

      expect(reviewable.reload.payload["continuation"]).to include("post_id" => approval_post.id)
      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:approved)
      expect(topic.reload.closed).to eq(true)
    end

    it "creates a category from an approval card authored by the agent's user" do
      agent_user = ai_agent.create_user!
      source_post = Fabricate(:post, topic: topic)
      tool_action =
        create_tool_action(
          tool_name: "create_category",
          params: {
            name: "Bug reports",
            reason: "Collect bug reports",
          },
          post_id: source_post.id,
        )
      reviewable = create_reviewable(tool_action)
      approval_post =
        Fabricate(
          :post,
          topic: topic,
          user: agent_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      reviewable.perform(admin, :approve, post_id: approval_post.id)

      expect(reviewable.reload).to be_approved
      expect(Category.find_by!(name: "Bug reports").user_id).to eq(admin.id)
    end

    it "rejects an approval card copied by an unrelated agent" do
      ai_agent.create_user!
      other_agent_user = Fabricate(:ai_agent).create_user!
      source_post = Fabricate(:post, topic: topic)
      reviewable = create_reviewable(create_tool_action(post_id: source_post.id))
      copied_post =
        Fabricate(
          :post,
          topic: topic,
          user: other_agent_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      expect { reviewable.perform(admin, :approve, post_id: copied_post.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
      expect(reviewable.reload).to be_pending
      expect(topic.reload.closed).to eq(false)
    end

    it "rejects an agent's approval card copied to another topic" do
      agent_user = ai_agent.create_user!
      source_post = Fabricate(:post, topic: topic)
      reviewable = create_reviewable(create_tool_action(post_id: source_post.id))
      copied_post =
        Fabricate(
          :post,
          user: agent_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      expect { reviewable.perform(admin, :approve, post_id: copied_post.id) }.to raise_error(
        Discourse::InvalidAccess,
      )
      expect(reviewable.reload).to be_pending
      expect(topic.reload.closed).to eq(false)
    end

    it "rejects inline approval from a bot post without its approval card", :aggregate_failures do
      source_post = Fabricate(:post, topic: topic)
      tool_action = create_tool_action(post_id: source_post.id)
      reviewable = create_reviewable(tool_action)
      other_post = Fabricate(:post, topic: topic, user: bot_user)

      expect { reviewable.perform(admin, :approve, post_id: other_post.id) }.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(reviewable.reload).to be_pending
      expect(topic.reload.closed).to eq(false)
    end

    it "rejects inline approval when another user copies its approval card", :aggregate_failures do
      source_post = Fabricate(:post, topic: topic)
      tool_action = create_tool_action(post_id: source_post.id)
      reviewable = create_reviewable(tool_action)
      copied_card_post =
        Fabricate(
          :post,
          topic: topic,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      expect { reviewable.perform(admin, :approve, post_id: copied_card_post.id) }.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(reviewable.reload).to be_pending
      expect(topic.reload.closed).to eq(false)
    end

    it "raises error when target is missing" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)
      tool_action.destroy!
      reviewable.reload

      expect { reviewable.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises error when tool class is not found" do
      tool_action = create_tool_action(tool_name: "nonexistent_tool")
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(admin, :approve) }.to raise_error(Discourse::InvalidAccess)
    end

    it "raises and stays pending when the tool returns an error result (e.g. stale target)" do
      source_post = Fabricate(:post, topic: topic)
      tool_action =
        create_tool_action(
          params: {
            topic_id: -999,
            closed: true,
            reason: "test",
          },
          post_id: source_post.id,
        )
      reviewable = create_reviewable(tool_action)
      approval_post =
        Fabricate(
          :post,
          topic: topic,
          user: bot_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      expect {
        expect { reviewable.perform(admin, :approve, post_id: approval_post.id) }.to raise_error(
          Discourse::InvalidAccess,
        )
      }.not_to change { Jobs::ResumeAiToolApproval.jobs.size }
      expect(reviewable.reload).to be_pending
      expect(reviewable.payload["continuation"]).to be_nil
    end

    it "raises and stays pending when the approver lacks permission at replay time" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "suspend_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)
      moderator = Fabricate(:moderator)

      # A plain moderator cannot suspend an admin, so the replayed tool fails.
      target_user.update!(admin: true)

      expect { reviewable.perform(moderator, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(reviewable.reload).to be_pending
      expect(target_user.reload.suspended?).to eq(false)
    end

    it "raises error when performed_by is a bot account" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(bot_user, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.closed).to eq(false)
    end

    it "attributes the action to the approving moderator for tools that opt into attribute_to_approver?" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "suspend_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(target_user.reload.suspended?).to eq(true)

      suspend_history = UserHistory.where(action: UserHistory.actions[:suspend_user]).last
      expect(suspend_history.acting_user_id).to eq(admin.id)
      expect(suspend_history.target_user_id).to eq(target_user.id)
      expect(suspend_history.reviewable_id).to eq(reviewable.id)
    end

    it "attributes a silence_user approval to the approving moderator" do
      target_user = Fabricate(:user)
      tool_action =
        create_tool_action(
          tool_name: "silence_user",
          params: {
            username: target_user.username,
            duration_days: 7,
            reason: "Spam",
          },
        )
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(target_user.reload.silenced?).to eq(true)

      silence_history = UserHistory.where(action: UserHistory.actions[:silence_user]).last
      expect(silence_history.acting_user_id).to eq(admin.id)
      expect(silence_history.target_user_id).to eq(target_user.id)
      expect(silence_history.reviewable_id).to eq(reviewable.id)
    end

    it "applies a change_site_setting approval credited to the approving admin" do
      tool_action =
        create_tool_action(
          tool_name: "change_site_setting",
          params: {
            setting_name: "min_post_length",
            value: "42",
            reason: "Testing",
          },
        )
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :approve)

      expect(result.success?).to eq(true)
      expect(SiteSetting.min_post_length).to eq(42)

      change_history =
        UserHistory.where(
          action: UserHistory.actions[:change_site_setting],
          subject: "min_post_length",
        ).last
      expect(change_history.acting_user_id).to eq(admin.id)
    end

    it "raises and stays pending when a non-admin moderator approves a change_site_setting action" do
      tool_action =
        create_tool_action(
          tool_name: "change_site_setting",
          params: {
            setting_name: "min_post_length",
            value: "42",
            reason: "Testing",
          },
        )
      reviewable = create_reviewable(tool_action)
      moderator = Fabricate(:moderator)

      expect { reviewable.perform(moderator, :approve) }.to raise_error(Discourse::InvalidAccess)
      expect(reviewable.reload).to be_pending
      expect(SiteSetting.min_post_length).not_to eq(42)
    end
  end

  describe "#perform_reject" do
    it "transitions to rejected without executing the tool" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      result = reviewable.perform(admin, :reject)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:rejected)
      expect(topic.reload.closed).to eq(false)
    end

    it "accepts inline rejection from the bot post containing its approval card" do
      source_post = Fabricate(:post, topic: topic)
      tool_action = create_tool_action(post_id: source_post.id)
      reviewable = create_reviewable(tool_action)
      approval_post =
        Fabricate(
          :post,
          topic: topic,
          user: bot_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      result = reviewable.perform(admin, :reject, post_id: approval_post.id)

      expect(result.success?).to eq(true)
      expect(result.transition_to).to eq(:rejected)
      expect(topic.reload.closed).to eq(false)
    end

    it "accepts inline rejection from the agent's user" do
      agent_user = ai_agent.create_user!
      source_post = Fabricate(:post, topic: topic)
      reviewable = create_reviewable(create_tool_action(post_id: source_post.id))
      approval_post =
        Fabricate(
          :post,
          topic: topic,
          user: agent_user,
          raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
        )

      expect { reviewable.perform(admin, :reject, post_id: approval_post.id) }.to change {
        Jobs::ResumeAiToolApproval.jobs.size
      }.by(1)

      expect(reviewable.reload).to be_rejected
      expect(topic.reload.closed).to eq(false)
    end

    it "resolves multiple inline reviews independently from the same bot post" do
      source_post = Fabricate(:post, topic: topic)
      first_reviewable = create_reviewable(create_tool_action(post_id: source_post.id))
      second_reviewable = create_reviewable(create_tool_action(post_id: source_post.id))
      approval_post = Fabricate(:post, topic: topic, user: bot_user, raw: <<~RAW)
            <div data-ai-tool-approval-reviewable-id='#{first_reviewable.id}'></div>
            <div data-ai-tool-approval-reviewable-id='#{second_reviewable.id}'></div>
          RAW

      first_result = first_reviewable.perform(admin, :reject, post_id: approval_post.id)

      expect(first_result.success?).to eq(true)
      expect(first_reviewable.reload).to be_rejected
      expect(second_reviewable.reload).to be_pending

      second_result = second_reviewable.perform(admin, :reject, post_id: approval_post.id)

      expect(second_result.success?).to eq(true)
      expect(second_reviewable.reload).to be_rejected
    end

    it "raises error when performed_by is a bot account" do
      tool_action = create_tool_action
      reviewable = create_reviewable(tool_action)

      expect { reviewable.perform(bot_user, :reject) }.to raise_error(Discourse::InvalidAccess)
    end
  end
end

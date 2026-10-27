# frozen_string_literal: true

module ExternalReviewablePlugin
  class ExternalEcho < DiscourseAi::Agents::Tools::Tool
    def self.signature
      { name: name, description: "Echoes an option", parameters: [] }
    end

    def self.name
      "ExternalEcho"
    end

    def self.accepted_options
      [option(:greeting, type: :string)]
    end

    def invoke
      return error_response("no greeting") if options[:greeting] != "hello"

      { status: "success" }
    end
  end
end

RSpec.describe ReviewableAiToolAction do
  fab!(:admin)
  fab!(:ai_agent)
  fab!(:topic)

  let(:bot_user) { Discourse.system_user }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    ai_agent.reload
  end

  def create_tool_action(tool_name: "close_topic", params: nil, post_id: nil, tool_options: {})
    params ||= { topic_id: topic.id, closed: true, reason: "Off-topic" }
    AiToolAction.create!(
      tool_name: tool_name,
      tool_parameters: params,
      tool_options: tool_options,
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
    it "rebuilds an externally registered tool with the options queued with the action" do
      DiscourseAi.register_tools(
        [ExternalReviewablePlugin::ExternalEcho],
        plugin: Plugin::Instance.new,
      )
      tool_action =
        create_tool_action(
          tool_name: "ExternalEcho",
          params: {
          },
          tool_options: {
            greeting: "hello",
          },
        )
      reviewable = create_reviewable(tool_action)

      expect(reviewable.perform(admin, :approve).success?).to eq(true)
    ensure
      DiscoursePluginRegistry._raw_external_ai_tools.reject! do |entry|
        entry[:value] == ExternalReviewablePlugin::ExternalEcho
      end
    end

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
      agent_user = ai_agent.user
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
      agent_user = ai_agent.user
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
      agent_user = ai_agent.user
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

  describe "#perform" do
    context "when the dsa_reporting_enabled site setting is enabled" do
      before do
        freeze_time
        SiteSetting.dsa_reporting_enabled = true
      end

      it "records a statement when an AI tool reviewable closes a topic" do
        post = Fabricate(:post, topic:)
        tool_action =
          create_tool_action(
            tool_name: "close_topic",
            params: {
              topic_id: topic.id,
              closed: true,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The topic was closed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"],
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable reopens a topic" do
        post = Fabricate(:post, topic:)
        topic.update!(closed: true)
        tool_action =
          create_tool_action(
            tool_name: "close_topic",
            params: {
              topic_id: topic.id,
              closed: false,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when an AI tool reviewable unlists a topic" do
        post = Fabricate(:post, topic:)
        tool_action =
          create_tool_action(
            tool_name: "unlist_topic",
            params: {
              topic_id: topic.id,
              unlisted: true,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The topic was unlisted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DEMOTED"],
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable lists a topic" do
        post = Fabricate(:post, topic:)
        topic.update!(visible: false)
        tool_action =
          create_tool_action(
            tool_name: "unlist_topic",
            params: {
              topic_id: topic.id,
              unlisted: false,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when an AI tool reviewable deletes a topic" do
        post = Fabricate(:post, topic:)
        tool_action =
          create_tool_action(
            tool_name: "delete_topic",
            params: {
              topic_id: topic.id,
              deleted: true,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The topic was removed.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable restores a topic" do
        post = Fabricate(:post, topic:)
        topic.trash!(admin)
        tool_action =
          create_tool_action(
            tool_name: "delete_topic",
            params: {
              topic_id: topic.id,
              deleted: false,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when an AI tool reviewable locks a post" do
        post = Fabricate(:post)
        tool_action =
          create_tool_action(
            tool_name: "lock_post",
            params: {
              post_id: post.id,
              locked: true,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The post was locked.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"],
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable unlocks a post" do
        post = Fabricate(:post)
        PostLocker.new(post, admin).lock
        tool_action =
          create_tool_action(
            tool_name: "lock_post",
            params: {
              post_id: post.id,
              locked: false,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a partly automated flagged post decision when a moderator approves an AI tool reviewable that hides it" do
        flagged = Fabricate(:reviewable_flagged_post)
        tool_action =
          create_tool_action(
            tool_name: "perform_reviewable_action",
            params: {
              reviewable_id: flagged.id,
              action_id: "agree_and_hide",
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: flagged.id)

        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "Access to the flagged post was disabled.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "No",
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => flagged.target.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        )
      end

      it "records a statement when an AI tool reviewable enables slow mode" do
        post = Fabricate(:post, topic:)
        tool_action =
          create_tool_action(
            tool_name: "set_slow_mode",
            params: {
              topic_id: topic.id,
              slow_mode_seconds: 60,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" =>
            "The topic was placed in slow mode, limiting how often users can reply.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_CONTENT_INTERACTION_RESTRICTED"],
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable disables slow mode" do
        post = Fabricate(:post, topic:)
        topic.update!(slow_mode_seconds: 60)
        tool_action =
          create_tool_action(
            tool_name: "set_slow_mode",
            params: {
              topic_id: topic.id,
              slow_mode_seconds: 0,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "records a statement when an AI tool reviewable edits a post" do
        post = Fabricate(:post)
        tool_action =
          create_tool_action(
            tool_name: "edit_post",
            params: {
              post_id: post.id,
              raw: "Corrected content for this moderated post.",
              edit_reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The post was edited.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_TEXT"],
          "content_date" => post.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "decision_visibility" => ["DECISION_VISIBILITY_OTHER"],
          "decision_visibility_other" => "Content edited",
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "records a statement when an AI tool reviewable suspends a user" do
        user = Fabricate(:user)
        tool_action =
          create_tool_action(
            tool_name: "suspend_user",
            params: {
              username: user.username,
              duration_days: 7,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The account was suspended.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_account" => "DECISION_ACCOUNT_SUSPENDED",
          "end_date_account_restriction" => 7.days.from_now.to_date.iso8601,
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "records a statement when an AI tool reviewable silences a user" do
        user = Fabricate(:user)
        tool_action =
          create_tool_action(
            tool_name: "silence_user",
            params: {
              username: user.username,
              duration_days: 7,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { reviewable.perform(admin, :approve) }.to change(DsaStatementOfRecord, :count).by(1)

        statement = DsaStatementOfRecord.find_by!(reviewable_id: reviewable.id)

        expect(statement).to be_pending
        expect(statement.payload).to eq(
          "territorial_scope" => DsaStatementOfRecord::TERRITORIAL_SCOPE,
          "decision_facts" => "The account had its ability to participate restricted.",
          "source_type" => "SOURCE_VOLUNTARY",
          "decision_ground" => "DECISION_GROUND_INCOMPATIBLE_CONTENT",
          "automated_detection" => "Yes",
          "content_type" => ["CONTENT_TYPE_OTHER"],
          "content_date" => user.created_at.to_date.iso8601,
          "application_date" => Date.current.iso8601,
          "content_type_other" => "User account",
          "decision_provision" => "DECISION_PROVISION_PARTIAL_SUSPENSION",
          "end_date_service_restriction" => 7.days.from_now.to_date.iso8601,
          "automated_decision" => "AUTOMATED_DECISION_PARTIALLY",
        )
      end

      it "creates no statement when an AI tool reviewable moves a topic to a private category" do
        post = Fabricate(:post, topic:)
        category = Fabricate(:private_category, group: Fabricate(:group))
        tool_action =
          create_tool_action(
            tool_name: "change_topic_category",
            params: {
              topic_id: topic.id,
              category_id: category.id,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when an AI tool reviewable moves a post to a private topic" do
        Fabricate(:post, topic:)
        post = Fabricate(:post, topic:)
        destination =
          Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
        Fabricate(:post, topic: destination)
        tool_action =
          create_tool_action(
            tool_name: "move_posts",
            params: {
              topic_id: topic.id,
              post_ids: [post.id],
              destination_topic_id: destination.id,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when an AI tool reviewable moves a topic to a public category" do
        post = Fabricate(:post, topic:)
        category = Fabricate(:category)
        tool_action =
          create_tool_action(
            tool_name: "change_topic_category",
            params: {
              topic_id: topic.id,
              category_id: category.id,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when an AI tool reviewable moves a post to a public topic" do
        Fabricate(:post, topic:)
        post = Fabricate(:post, topic:)
        destination = Fabricate(:topic)
        Fabricate(:post, topic: destination)
        tool_action =
          create_tool_action(
            tool_name: "move_posts",
            params: {
              topic_id: topic.id,
              post_ids: [post.id],
              destination_topic_id: destination.id,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when an AI tool reviewable creates a category" do
        tool_action =
          create_tool_action(
            tool_name: "create_category",
            params: {
              name: "Bug reports",
              reason: "Collect reports",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :approve)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end

      it "creates no statement when a moderator rejects an AI tool reviewable" do
        tool_action =
          create_tool_action(
            tool_name: "close_topic",
            params: {
              topic_id: topic.id,
              closed: true,
              reason: "Moderation",
            },
          )
        reviewable = create_reviewable(tool_action)

        expect { expect(reviewable.perform(admin, :reject)).to be_success }.not_to change(
          DsaStatementOfRecord,
          :count,
        )
      end
    end
  end
end

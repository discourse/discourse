# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FlagUser::V1 do
  fab!(:moderator)
  fab!(:admin)
  fab!(:target, :user)
  fab!(:workflow, :discourse_workflows_workflow)

  let(:attribution) do
    I18n.t("discourse_workflows.flag_user.flagged_by_workflow", workflow_name: workflow.name)
  end

  def flag(configuration = {}, item = { "json" => {} }, &block)
    config = { "username" => target.username }.merge(configuration)
    execute_node_output(configuration: config, item: item, workflow: workflow, &block)
      .first
      .first
      .fetch("json")
  end

  describe "#execute" do
    it "adds the user to the review queue", :aggregate_failures do
      result = nil

      expect { result = flag }.to change { ReviewableUser.pending.where(target: target).count }.by(
        1,
      )

      reviewable = ReviewableUser.pending.find_by(target: target)
      score = reviewable.reviewable_scores.last

      expect(score.reviewable_score_type).to eq(ReviewableScore.types[:needs_approval])
      expect(score.user).to eq(Discourse.system_user)
      expect(score.reason).to eq("workflow_flagged_user")
      expect(result).to include(
        "user_id" => target.id,
        "username" => target.username,
        "reviewable_id" => reviewable.id,
        "reviewable_status" => "pending",
        "reviewable_created" => true,
        "score_added" => true,
        "user_approved" => false,
      )
    end

    it "matches the declared output contract" do
      expect(flag).to match_node_output_schema(
        described_class,
        configuration: {
          "username" => target.username,
        },
      )
    end

    it "snapshots the same payload fields core's suspect user job does" do
      avatar = Fabricate(:upload)
      target.update!(uploaded_avatar_id: avatar.id)
      target.user_profile.update!(bio_raw: "Buy my links", website: "https://spam.example")

      flag

      payload = ReviewableUser.find_by(target: target).payload

      expect(payload).to include(
        "username" => target.username,
        "name" => target.name,
        "email" => target.email,
        "bio" => "Buy my links",
        "website" => "https://spam.example",
        "avatar_url" => Discourse.store.cdn_url(avatar.url),
      )
    end

    it "leaves the reviewable's spam flag alone" do
      flag

      expect(ReviewableUser.find_by(target: target).potential_spam).to eq(false)
    end

    it "records the workflow attribution as a note rather than in the score reason" do
      flag("reason" => "Profile is link spam")

      reviewable = ReviewableUser.find_by(target: target)
      note = reviewable.reviewable_notes.last

      expect(note.user).to eq(Discourse.system_user)
      expect(note.content).to eq("#{attribution}\n\nProfile is link spam")
      expect(reviewable.reviewable_scores.last.reason).to eq("workflow_flagged_user")
    end

    it "renders the score reason as a translated sentence in the review queue" do
      flag

      score = ReviewableUser.find_by(target: target).reviewable_scores.last
      serialized = ReviewableScoreSerializer.new(score, scope: moderator.guardian, root: nil)

      expect(serialized.reason).to match_html(<<~HTML)
        <p>A workflow added this user to the review queue.</p>
      HTML
    end

    it "offers moderators the approve and reject actions" do
      flag

      reviewable = ReviewableUser.find_by(target: target).reload

      expect(reviewable.actions_for(moderator.guardian).to_a.map(&:server_action)).to eq(
        %w[approve_user delete_user delete_user_block],
      )
    end
  end

  describe "idempotency" do
    it "does not add a second score or note when the same flag runs again" do
      flag("reason" => "Profile is link spam")

      expect { flag("reason" => "Profile is link spam") }.to not_change {
        ReviewableScore.count
      }.and not_change { ReviewableNote.count }

      expect(flag("reason" => "Profile is link spam")).to include(
        "score_added" => false,
        "reviewable_created" => false,
      )
    end
  end

  describe "resolved reviewables" do
    before { ReviewableUser.create_for(target).update!(status: Reviewable.statuses[:approved]) }

    it "leaves a settled moderator decision alone and explains why" do
      hints = nil
      result = nil

      expect do
        result =
          execute_node_output(
            configuration: {
              "username" => target.username,
            },
            workflow: workflow,
          ) { |ctx| hints = ctx.execution_hints }.first.first.fetch("json")
      end.to not_change { ReviewableUser.find_by(target: target).status }.and not_change {
              ReviewableScore.count
            }

      expect(result).to include("reviewable_status" => "approved", "score_added" => false)
      expect(hints).to eq(
        [
          {
            "message" =>
              I18n.t(
                "discourse_workflows.hints.flag_user.already_resolved",
                username: target.username,
                status: "approved",
              ),
            "location" => "outputPane",
          },
        ],
      )
    end

    it "reopens the review when explicitly asked to" do
      result = flag("reopen_resolved" => true)

      expect(ReviewableUser.find_by(target: target).status).to eq("pending")
      expect(result).to include("reviewable_status" => "pending", "score_added" => true)
    end

    it "reopens when an expression resolves to a truthy string" do
      result =
        flag({ "reopen_resolved" => "={{ $json.reopen }}" }, { "json" => { "reopen" => "true" } })

      expect(ReviewableUser.find_by(target: target).status).to eq("pending")
      expect(result).to include("score_added" => true)
    end
  end

  describe "guards" do
    it "rejects a non-staff actor" do
      expect { flag("actor_username" => target.username) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.flag_user.actor_not_staff"),
      ).and not_change { Reviewable.count }
    end

    it "rejects the anonymous actor" do
      expect { flag("actor_username" => "anonymous") }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.flag_user.actor_not_staff"),
      ).and not_change { Reviewable.count }
    end

    it "refuses to flag staff" do
      expect { flag("username" => moderator.username) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_workflows.errors.flag_user.cannot_flag_staff",
          username: moderator.username,
        ),
      )
    end

    it "refuses to flag automated accounts" do
      expect { flag("username" => Discourse.system_user.username) }.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t(
          "discourse_workflows.errors.flag_user.cannot_flag_staff",
          username: Discourse.system_user.username,
        ),
      )
    end

    it "refuses a staff actor flagging their own account" do
      expect { flag("username" => admin.username, "actor_username" => admin.username) }.to(
        raise_error(
          DiscourseWorkflows::NodeError,
          I18n.t(
            "discourse_workflows.errors.flag_user.cannot_flag_staff",
            username: admin.username,
          ),
        ),
      )
    end

    it "raises when the username does not resolve" do
      expect { flag("username" => "nope") }.to raise_error(
        DiscourseWorkflows::NodeError,
        "User 'nope' not found",
      )
    end
  end

  describe "expressions" do
    fab!(:other_user, :user)

    it "resolves the username per item" do
      output =
        execute_node_output(
          configuration: {
            "username" => "={{ $json.username }}",
          },
          input_items: [
            { "json" => { "username" => target.username } },
            { "json" => { "username" => other_user.username } },
          ],
          workflow: workflow,
        ).first

      expect(output.map { |item| item.dig("json", "user_id") }).to eq([target.id, other_user.id])
    end

    it "resolves a nested username" do
      result =
        flag(
          { "username" => "={{ $json.user.username }}" },
          { "json" => { "user" => { "username" => target.username } } },
        )

      expect(result).to include("user_id" => target.id)
    end
  end
end

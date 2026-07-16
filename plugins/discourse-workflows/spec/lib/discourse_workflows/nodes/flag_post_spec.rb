# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::FlagPost::V1 do
  fab!(:moderator)
  fab!(:author, :user)
  fab!(:post) { Fabricate(:post, user: author) }
  fab!(:workflow, :discourse_workflows_workflow)

  let(:attribution) do
    I18n.t("discourse_workflows.flag_post.flagged_by_workflow", workflow_name: workflow.name)
  end

  describe "#execute" do
    it "adds the post to the review queue", :aggregate_failures do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "post_id" => post.id.to_s,
              "flag_type" => "review",
            },
            workflow: workflow,
          )
      end.to change { ReviewablePost.pending.where(target: post).count }.by(1)

      reviewable = ReviewablePost.pending.find_by(target: post)
      score = reviewable.reviewable_scores.last

      expect(score.reviewable_score_type).to eq(ReviewableScore.types[:needs_approval])
      expect(score.user).to eq(Discourse.system_user)
      expect(score.reason).to eq(attribution)
      expect(post.reload.hidden?).to eq(false)
      expect(result).to include(
        "post_id" => post.id,
        "flag_type" => "review",
        "reviewable_id" => reviewable.id,
        "post_hidden" => false,
        "post_deleted" => false,
        "user_silenced" => false,
      )
    end

    it "appends the configured reason to the moderator-facing score reason, escaping HTML" do
      execute_node(
        configuration: {
          "post_id" => post.id.to_s,
          "flag_type" => "review",
          "reason" => "Contains suspicious <script>alert(1)</script> links",
        },
        workflow: workflow,
      )

      score = ReviewablePost.pending.find_by(target: post).reviewable_scores.last
      expect(score.reason).to eq(
        "#{attribution}<br>Contains suspicious &lt;script&gt;alert(1)&lt;/script&gt; links",
      )
    end

    it "reuses a pending flagged post reviewable instead of creating a second review item",
       :aggregate_failures do
      existing = Fabricate(:reviewable_flagged_post, target: post, topic: post.topic)

      result =
        execute_node(
          configuration: {
            "post_id" => post.id.to_s,
            "flag_type" => "review",
          },
          workflow: workflow,
        )

      score =
        existing.reviewable_scores.find_by(
          user: Discourse.system_user,
          reviewable_score_type: ReviewableScore.types[:needs_approval],
        )

      expect(result["reviewable_id"]).to eq(existing.id)
      expect(ReviewablePost.where(target: post)).to be_empty
      expect(score.reason).to eq(attribution)
    end

    it "adds a single score when the same workflow flags the same post twice" do
      execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "review" })

      expect do
        execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "review" })
      end.not_to change { ReviewableScore.count }
    end

    it "hides the post with review_hide", :aggregate_failures do
      result =
        execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "review_hide" })

      expect(post.reload.hidden?).to eq(true)
      expect(post.deleted_at).to be_nil
      expect(result).to include("post_hidden" => true, "post_deleted" => false)
    end

    it "soft-deletes the post with review_delete", :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "post_id" => post.id.to_s,
            "flag_type" => "review_delete",
            "actor_username" => moderator.username,
          },
        )

      expect(post.reload.deleted_at).to be_present
      expect(post.deleted_by_id).to eq(moderator.id)
      expect(author.reload.silenced?).to eq(false)
      expect(ReviewablePost.pending.where(target: post).count).to eq(1)
      expect(result).to include("post_deleted" => true, "user_silenced" => false)
    end

    it "keeps a pending review item when deleting a post that already has a pending flag",
       :aggregate_failures do
      Fabricate(:reviewable_flagged_post, target: post, topic: post.topic)

      execute_node(
        configuration: {
          "post_id" => post.id.to_s,
          "flag_type" => "review_delete",
          "actor_username" => moderator.username,
        },
      )

      expect(post.reload.deleted_at).to be_present
      expect(Reviewable.pending.where(target: post).count).to eq(1)
    end

    it "soft-deletes the post and silences the author with review_delete_silence",
       :aggregate_failures do
      result =
        execute_node(
          configuration: {
            "post_id" => post.id.to_s,
            "flag_type" => "review_delete_silence",
            "actor_username" => moderator.username,
          },
        )

      expect(post.reload.deleted_at).to be_present
      expect(author.reload.silenced?).to eq(true)
      expect(result).to include("post_deleted" => true, "user_silenced" => true)
    end

    it "flags the post as spam and hides it", :aggregate_failures do
      result = nil

      expect do
        result =
          execute_node(
            configuration: {
              "post_id" => post.id.to_s,
              "flag_type" => "spam",
              "actor_username" => moderator.username,
            },
          )
      end.to change {
        PostAction.where(post: post, post_action_type_id: PostActionType.types[:spam]).count
      }.by(1)

      reviewable = ReviewableFlaggedPost.pending.find_by(target: post)

      expect(PostAction.last.user).to eq(moderator)
      expect(post.reload.hidden?).to eq(true)
      expect(post.topic.reload.visible).to eq(false)
      expect(author.reload.silenced?).to eq(false)
      expect(result).to include(
        "flag_type" => "spam",
        "reviewable_id" => reviewable.id,
        "post_hidden" => true,
        "post_deleted" => false,
        "user_silenced" => false,
      )
    end

    it "flags the post as spam and silences the author with spam_silence", :aggregate_failures do
      result =
        execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "spam_silence" })

      expect(post.reload.hidden?).to eq(true)
      expect(author.reload.silenced?).to eq(true)
      expect(result).to include("post_hidden" => true, "user_silenced" => true)
    end

    it "promotes a pending review item to a flagged post reviewable when flagging as spam",
       :aggregate_failures do
      execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "review" })
      reviewable = ReviewablePost.pending.find_by(target: post)

      execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "spam" })

      expect(Reviewable.find(reviewable.id).type).to eq(ReviewableFlaggedPost.name)
      expect(Reviewable.where(target: post).count).to eq(1)
    end

    it "raises without silencing the author when a hidden post is flagged as spam",
       :aggregate_failures do
      post.hide!(PostActionType.types[:spam])

      expect do
        execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "spam_silence" })
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.flag_post.cannot_flag"),
      )

      expect(author.reload.silenced?).to eq(false)
    end

    it "skips silencing when the post author no longer exists", :aggregate_failures do
      post.update_columns(user_id: nil)

      result =
        execute_node(
          configuration: {
            "post_id" => post.id.to_s,
            "flag_type" => "review_delete_silence",
            "actor_username" => moderator.username,
          },
        )

      expect(post.reload.deleted_at).to be_present
      expect(result).to include("post_deleted" => true, "user_silenced" => false)
    end

    it "flags each input item's post separately", :aggregate_failures do
      second_post = Fabricate(:post)

      output =
        execute_node_output(
          configuration: {
            "post_id" => "={{ $json.post_id }}",
            "flag_type" => "review",
          },
          input_items: [
            { "json" => { "post_id" => post.id } },
            { "json" => { "post_id" => second_post.id } },
          ],
        )

      items = output.first
      expect(items.map { |item| item.dig("json", "post_id") }).to eq([post.id, second_post.id])
      expect(ReviewablePost.pending.where(target: post).count).to eq(1)
      expect(ReviewablePost.pending.where(target: second_post).count).to eq(1)
    end

    it "raises when the acting user cannot see the post" do
      pm_post = Fabricate(:private_message_post)

      expect do
        execute_node(
          configuration: {
            "post_id" => pm_post.id.to_s,
            "flag_type" => "review",
            "actor_username" => moderator.username,
          },
        )
      end.to raise_error(Discourse::InvalidAccess)
    end

    it "resolves dynamic post id and flag type expressions" do
      result =
        execute_node(
          configuration: {
            "post_id" => "={{ $json.post.id }}",
            "flag_type" => "={{ $json.severity }}",
          },
          item: {
            "json" => {
              "post" => {
                "id" => post.id,
              },
              "severity" => "review_hide",
            },
          },
        )

      expect(post.reload.hidden?).to eq(true)
      expect(result).to include("post_id" => post.id, "flag_type" => "review_hide")
    end

    it "raises when the flag type is unknown" do
      expect do
        execute_node(configuration: { "post_id" => post.id.to_s, "flag_type" => "nuke" })
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.flag_post.unknown_flag_type", flag_type: "nuke"),
      )
    end

    it "raises when the acting user is not a staff member" do
      non_staff = Fabricate(:user)

      expect do
        execute_node(
          configuration: {
            "post_id" => post.id.to_s,
            "flag_type" => "review",
            "actor_username" => non_staff.username,
          },
        )
      end.to raise_error(
        DiscourseWorkflows::NodeError,
        I18n.t("discourse_workflows.errors.flag_post.actor_not_staff"),
      )
    end
  end
end

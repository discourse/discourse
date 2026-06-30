# frozen_string_literal: true

describe DiscourseAi::GuardianExtensions do
  fab!(:user)
  fab!(:group)
  fab!(:topic)

  before do
    enable_current_plugin
    group.add(user)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_summary_gists_enabled = true
  end

  let(:anon_guardian) { Guardian.new }
  let(:guardian) { Guardian.new(user) }

  def create_cached_summary(topic)
    strategy = DiscourseAi::Summarization::Strategies::TopicSummary.new(topic)
    content_sha = AiSummary.build_sha(strategy.targets_data.map { |target| target[:id] }.join)

    Fabricate(
      :ai_summary,
      target: topic,
      original_content_sha: content_sha,
      highest_target_number: topic.highest_post_number,
    )
  end

  describe "#can_see_summary?" do
    context "when the user cannot generate a summary" do
      before { assign_agent_to(:ai_summarization_agent, []) }

      it "returns false" do
        expect(guardian.can_see_summary?(topic, cached_summary: nil)).to eq(false)
      end

      it "returns true if there is a cached summary" do
        cached_summary = create_cached_summary(topic)

        expect(guardian.can_see_summary?(topic, cached_summary: cached_summary)).to eq(true)
      end
    end

    context "when the user can generate a summary" do
      before { assign_agent_to(:ai_summarization_agent, [group.id]) }

      it "returns true if the user group is present in the ai_custom_summarization_allowed_groups_map setting" do
        expect(guardian.can_see_summary?(topic, cached_summary: nil)).to eq(true)
      end
    end

    context "when the topic is a PM" do
      before { assign_agent_to(:ai_summarization_agent, [group.id]) }
      let(:pm) { Fabricate(:private_message_topic) }

      it "returns false" do
        expect(guardian.can_see_summary?(pm, cached_summary: nil)).to eq(false)
      end

      it "returns true if user is in a group that is allowed summaries" do
        SiteSetting.ai_pm_summarization_allowed_groups = group.id
        expect(guardian.can_see_summary?(pm, cached_summary: nil)).to eq(true)
      end
    end

    context "when there is no user" do
      it "returns false for anons" do
        expect(anon_guardian.can_see_summary?(topic, cached_summary: nil)).to eq(false)
      end

      it "returns true for anons when there is a fresh cached summary" do
        cached_summary = create_cached_summary(topic)

        expect(anon_guardian.can_see_summary?(topic, cached_summary: cached_summary)).to eq(true)
      end
    end

    context "when summary is provided" do
      it "returns false for non-regenerators when the provided summary is outdated" do
        summary = Fabricate(:ai_summary, target: topic)
        summary.mark_as_outdated

        expect(anon_guardian.can_see_summary?(topic, cached_summary: summary)).to eq(false)
      end

      it "returns true for non-regenerators when the provided summary is fresh" do
        summary = create_cached_summary(topic)

        expect(anon_guardian.can_see_summary?(topic, cached_summary: summary)).to eq(true)
      end
    end
  end

  describe "#can_see_gists?" do
    before { assign_agent_to(:ai_summary_gists_agent, [group.id]) }
    let(:guardian) { Guardian.new(user) }

    context "when access is restricted to the user's group" do
      it "returns false when there is a user who is a member of an allowed group" do
        expect(guardian.can_see_gists?).to eq(true)
      end

      it "returns false for anons" do
        expect(anon_guardian.can_see_gists?).to eq(false)
      end

      it "returns false for non-group members" do
        other_user_guardian = Guardian.new(Fabricate(:user))

        expect(other_user_guardian.can_see_gists?).to eq(false)
      end
    end

    context "when access is set to everyone" do
      before { assign_agent_to(:ai_summary_gists_agent, [Group::AUTO_GROUPS[:everyone]]) }

      it "returns true" do
        expect(guardian.can_see_gists?).to eq(true)
      end

      it "returns false for anons" do
        expect(anon_guardian.can_see_gists?).to eq(true)
      end
    end
  end

  describe "#can_create_ai_artifact?" do
    fab!(:admin)
    fab!(:moderator)
    fab!(:allowed_group, :group)

    before { SiteSetting.ai_artifact_security = "lax" }

    it "returns false when anonymous" do
      expect(Guardian.new.can_create_ai_artifact?).to eq(false)
    end

    it "returns false when ai_artifact_security is disabled" do
      allowed_group.add(user)
      SiteSetting.ai_artifact_allowed_groups = allowed_group.id.to_s
      SiteSetting.ai_artifact_security = "disabled"

      expect(Guardian.new(user).can_create_ai_artifact?).to eq(false)
    end

    it "returns true for admins regardless of group membership" do
      SiteSetting.ai_artifact_allowed_groups = ""

      expect(Guardian.new(admin).can_create_ai_artifact?).to eq(true)
    end

    it "returns true for users in ai_artifact_allowed_groups" do
      allowed_group.add(user)
      SiteSetting.ai_artifact_allowed_groups = allowed_group.id.to_s

      expect(Guardian.new(user).can_create_ai_artifact?).to eq(true)
    end

    it "returns false for users not in ai_artifact_allowed_groups" do
      SiteSetting.ai_artifact_allowed_groups = ""

      expect(Guardian.new(user).can_create_ai_artifact?).to eq(false)
    end

    it "returns false for moderators who are not in ai_artifact_allowed_groups" do
      SiteSetting.ai_artifact_allowed_groups = ""

      expect(Guardian.new(moderator).can_create_ai_artifact?).to eq(false)
    end
  end

  describe "#can_view_ai_artifact?" do
    fab!(:owner, :user)
    fab!(:other_user, :user)
    fab!(:pm_topic) { Fabricate(:private_message_topic, user: owner) }
    fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: owner) }
    fab!(:artifact) { Fabricate(:ai_artifact, user: owner, post: pm_post) }

    it "returns true for public artifacts even without authentication" do
      artifact.update!(metadata: { public: true })

      expect(Guardian.new.can_view_ai_artifact?(artifact)).to eq(true)
    end

    it "returns true to the artifact owner even when the artifact is not associated to a post" do
      artifact.update!(post_id: nil)

      expect(Guardian.new(owner).can_view_ai_artifact?(artifact)).to eq(true)
    end

    it "returns false to anonymous viewers when the artifact is not associated to a post and non-public" do
      artifact.update!(post_id: nil)

      expect(Guardian.new.can_view_ai_artifact?(artifact)).to eq(false)
    end

    it "returns true to users who can see the post" do
      expect(Guardian.new(owner).can_view_ai_artifact?(artifact)).to eq(true)
    end

    it "returns false to users who cannot see the post" do
      expect(Guardian.new(other_user).can_view_ai_artifact?(artifact)).to eq(false)
    end
  end

  describe "#can_edit_ai_artifact?" do
    fab!(:owner, :user)
    fab!(:admin)
    fab!(:other_user, :user)
    fab!(:allowed_group, :group)
    fab!(:artifact) { Fabricate(:ai_artifact, user: owner) }

    before do
      SiteSetting.ai_artifact_security = "lax"
      allowed_group.add(owner)
      SiteSetting.ai_artifact_allowed_groups = allowed_group.id.to_s
    end

    it "returns false when anonymous" do
      expect(Guardian.new.can_edit_ai_artifact?(artifact)).to eq(false)
    end

    it "returns true for the artifact owner" do
      expect(Guardian.new(owner).can_edit_ai_artifact?(artifact)).to eq(true)
    end

    it "returns true for admins" do
      expect(Guardian.new(admin).can_edit_ai_artifact?(artifact)).to eq(true)
    end

    it "returns false for users who do not own the artifact" do
      expect(Guardian.new(other_user).can_edit_ai_artifact?(artifact)).to eq(false)
    end

    it "returns false for moderators who do not own the artifact" do
      moderator = Fabricate(:moderator)

      expect(Guardian.new(moderator).can_edit_ai_artifact?(artifact)).to eq(false)
    end

    it "returns false when ai_artifact_security is disabled" do
      SiteSetting.ai_artifact_security = "disabled"

      expect(Guardian.new(owner).can_edit_ai_artifact?(artifact)).to eq(false)
      expect(Guardian.new(admin).can_edit_ai_artifact?(artifact)).to eq(false)
    end

    it "returns false when the owner is no longer in ai_artifact_allowed_groups" do
      SiteSetting.ai_artifact_allowed_groups = ""

      expect(Guardian.new(owner).can_edit_ai_artifact?(artifact)).to eq(false)
    end
  end
end

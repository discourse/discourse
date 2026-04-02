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
end

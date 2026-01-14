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

  describe "#can_see_summary?" do
    context "when the user cannot generate a summary" do
      before { assign_persona_to(:ai_summarization_persona, []) }

      it "returns false" do
        expect(guardian.can_see_summary?(topic)).to eq(false)
      end

      it "returns true if there is a cached summary" do
        Fabricate(:ai_summary, target: topic)

        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end

    context "when the user can generate a summary" do
      before { assign_persona_to(:ai_summarization_persona, [group.id]) }

      it "returns true if the user group is present in the ai_custom_summarization_allowed_groups_map setting" do
        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end

    context "when the topic is a PM" do
      before { assign_persona_to(:ai_summarization_persona, [group.id]) }
      let(:pm) { Fabricate(:private_message_topic) }

      it "returns false" do
        expect(guardian.can_see_summary?(pm)).to eq(false)
      end

      it "returns true if user is in a group that is allowed summaries" do
        SiteSetting.ai_pm_summarization_allowed_groups = group.id
        expect(guardian.can_see_summary?(pm)).to eq(true)
      end
    end

    context "when there is no user" do
      it "returns false for anons" do
        expect(anon_guardian.can_see_summary?(topic)).to eq(false)
      end

      it "returns true for anons when there is a cached summary" do
        Fabricate(:ai_summary, target: topic)

        expect(guardian.can_see_summary?(topic)).to eq(true)
      end
    end
  end

  describe "#can_see_gists?" do
    before { assign_persona_to(:ai_summary_gists_persona, [group.id]) }
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
      before { assign_persona_to(:ai_summary_gists_persona, [Group::AUTO_GROUPS[:everyone]]) }

      it "returns true" do
        expect(guardian.can_see_gists?).to eq(true)
      end

      it "returns false for anons" do
        expect(anon_guardian.can_see_gists?).to eq(true)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Jobs::StreamDiscoverReply do
  subject(:job) { described_class.new }

  before { enable_current_plugin }

  describe "#execute" do
    fab!(:user)
    fab!(:llm_model)
    fab!(:group)
    fab!(:ai_persona) do
      Fabricate(:ai_persona, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
    end

    before do
      SiteSetting.ai_discover_enabled = true
      SiteSetting.ai_discover_persona = ai_persona.id
      group.add(user)
    end

    def with_responses(responses)
      DiscourseAi::Completions::Llm.with_prepared_responses(responses) { yield }
    end

    it "publishes updates with a partial summary" do
      with_responses(["dummy"]) do
        messages =
          MessageBus.track_publish("/discourse-ai/discoveries") do
            job.execute(user_id: user.id, query: "Testing search")
          end

        partial_update = messages.first.data
        expect(partial_update[:done]).to eq(false)
        expect(partial_update[:model_used]).to eq(llm_model.display_name)
        expect(partial_update[:ai_discover_reply]).to eq("dummy")
      end
    end

    it "publishes a final update to signal we're done" do
      with_responses(["dummy"]) do
        messages =
          MessageBus.track_publish("/discourse-ai/discoveries") do
            job.execute(user_id: user.id, query: "Testing search")
          end

        final_update = messages.last.data
        expect(final_update[:done]).to eq(true)

        expect(final_update[:model_used]).to eq(llm_model.display_name)
        expect(final_update[:ai_discover_reply]).to eq("dummy")
      end
    end
  end
end

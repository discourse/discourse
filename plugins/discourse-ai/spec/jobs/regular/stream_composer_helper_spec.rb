# frozen_string_literal: true

RSpec.describe Jobs::StreamComposerHelper do
  subject(:job) { described_class.new }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
  end

  describe "#execute" do
    let!(:input) { "I liek to eet pie fur brakefast becuz it is delishus." }
    fab!(:user) { Fabricate(:leader) }

    before do
      Group.find(Group::AUTO_GROUPS[:trust_level_3]).add(user)
      SiteSetting.ai_helper_enabled = true
    end

    describe "validates params" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::PROOFREAD }

      it "does nothing if there is no user" do
        channel = "/some/channel"
        messages =
          MessageBus.track_publish(channel) do
            job.execute(
              user_id: nil,
              text: input,
              prompt: mode,
              force_default_locale: false,
              client_id: "123",
              progress_channel: channel,
            )
          end

        expect(messages).to be_empty
      end

      it "does nothing if there is no text" do
        channel = "/some/channel"
        messages =
          MessageBus.track_publish(channel) do
            job.execute(
              user_id: user.id,
              text: nil,
              prompt: mode,
              force_default_locale: false,
              client_id: "123",
              progress_channel: channel,
            )
          end

        expect(messages).to be_empty
      end
    end

    context "when all params are provided" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::PROOFREAD }

      it "publishes updates with a partial result" do
        proofread_result = "I like to eat pie for breakfast because it is delicious."
        channel = "/channel/123"

        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_result]) do
          messages =
            MessageBus.track_publish(channel) do
              job.execute(
                user_id: user.id,
                text: input,
                prompt: mode,
                force_default_locale: true,
                client_id: "123",
                progress_channel: channel,
              )
            end

          partial_result_update = messages.first.data
          expect(partial_result_update[:done]).to eq(false)
          expect(partial_result_update[:result]).to eq(proofread_result)
        end
      end

      it "publishes a final update to signal we're done" do
        proofread_result = "I like to eat pie for breakfast because it is delicious."
        channel = "/channel/123"

        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_result]) do
          messages =
            MessageBus.track_publish(channel) do
              job.execute(
                user_id: user.id,
                text: input,
                prompt: mode,
                force_default_locale: true,
                client_id: "123",
                progress_channel: channel,
              )
            end

          final_update = messages.last.data
          expect(final_update[:result]).to eq(proofread_result)
          expect(final_update[:done]).to eq(true)
        end
      end
    end
  end
end

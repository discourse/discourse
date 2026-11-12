# frozen_string_literal: true

RSpec.describe DiscourseAi::Configuration::LlmValidator do
  before { enable_current_plugin }

  describe "#valid_value?" do
    let(:validator) { described_class.new(name: :ai_default_llm_model) }

    fab!(:llm_model)

    before do
      assign_fake_provider_to(:ai_default_llm_model)
      SiteSetting.ai_helper_enabled = false
      SiteSetting.ai_summarization_enabled = false
      SiteSetting.ai_embeddings_semantic_search_enabled = false
      SiteSetting.ai_translation_enabled = false
    end

    it "returns true when no modules are enabled and value is empty string" do
      expect(validator.valid_value?("")).to eq(true)
    end

    it "returns false when a module is enabled and value is empty string" do
      SiteSetting.ai_helper_enabled = true
      expect(validator.valid_value?("")).to eq(false)
      expect(validator.error_message).to include("ai_helper_enabled")
    end

    it "returns false when multiple modules are enabled and value is empty string" do
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_summarization_enabled = true
      expect(validator.valid_value?("")).to eq(false)
      expect(validator.error_message).to include("ai_helper_enabled, ai_summarization_enabled")
    end

    it "returns true for non-empty values regardless of module state" do
      SiteSetting.ai_helper_enabled = true
      SiteSetting.ai_summarization_enabled = true

      DiscourseAi::Completions::Llm.with_prepared_responses(%w[ok ok]) do
        expect(validator.valid_value?(llm_model)).to eq(true)
      end
    end
  end

  describe "#run_test" do
    let(:validator) { described_class.new }

    fab!(:llm_model)

    it "exercises both non-streaming and streaming completions" do
      prompts =
        DiscourseAi::Completions::Llm.with_prepared_responses(%w[ok ok]) do |_, _, p|
          validator.run_test(llm_model)
          p
        end

      expect(prompts.length).to eq(2)
      expect(validator.last_failed_mode).to be_nil
    end

    it "marks non-streaming failure when the first probe returns nothing" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["", "ok"]) do
        expect { validator.run_test(llm_model) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
      end

      expect(validator.last_failed_mode).to eq(:non_streaming)
    end

    it "marks streaming failure when the streaming probe returns nothing" do
      DiscourseAi::Completions::Llm.with_prepared_responses(["ok", ""]) do
        expect { validator.run_test(llm_model) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
        )
      end

      expect(validator.last_failed_mode).to eq(:streaming)
    end

    it "gives up with a timeout error when the provider is too slow to respond" do
      stub_const(described_class, :TEST_TIMEOUT_SECONDS, 0.1) do
        gemini =
          Fabricate(
            :llm_model,
            provider: "google",
            url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-test",
          )

        stub_request(:post, /generativelanguage.googleapis.com/).to_return do
          sleep 1
          { status: 503, body: { error: { code: 503, status: "UNAVAILABLE" } }.to_json }
        end

        expect { validator.run_test(gemini) }.to raise_error(
          DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
          I18n.t("discourse_ai.llm.configuration.test_timeout", count: 0.1),
        )
      end

      expect(validator.last_failed_mode).to eq(:non_streaming)
      expect(WebMock).to have_requested(:post, /generativelanguage.googleapis.com/).once
    end

    context "when the provider stalls before responding" do
      let(:server) { TCPServer.new("127.0.0.1", 0) }
      let!(:server_thread) do
        Thread.new do
          held = []
          loop { held << server.accept }
        rescue StandardError
          nil
        end
      end

      before do
        WebMock.disable!
        FinalDestination::SSRFDetector.stubs(:lookup_and_filter_ips).returns(["127.0.0.1"])
      end

      after do
        WebMock.enable!
        server_thread.kill
        server.close
      end

      it "gives up within the budget even while the TLS handshake hangs" do
        stalled_model =
          Fabricate(:anthropic_model, url: "https://127.0.0.1:#{server.addr[1]}/v1/messages")
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        stub_const(described_class, :TEST_TIMEOUT_SECONDS, 0.5) do
          expect { validator.run_test(stalled_model) }.to raise_error(
            DiscourseAi::Completions::Endpoints::Base::CompletionFailed,
            I18n.t("discourse_ai.llm.configuration.test_timeout", count: 0.5),
          )
        end

        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
      end
    end
  end
end

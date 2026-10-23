# frozen_string_literal: true

RSpec.describe DiscourseAi::AskAi::Ask do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:query) }

    it do
      is_expected.to validate_length_of(:query).is_at_most(
        DiscourseAi::Discoveries::MAX_QUERY_LENGTH,
      )
    end

    it { is_expected.not_to allow_value("pass\0word").for(:query) }
    it { is_expected.to allow_value(SecureRandom.uuid).for(:request_id) }
    it { is_expected.not_to allow_values(nil, "abc", "123").for(:request_id) }
    it { is_expected.to allow_values(nil, "topic:12", "category:3 tag:howto").for(:scope) }
    it { is_expected.not_to allow_values("topic:abc", "in:messages").for(:scope) }

    describe "normalisation" do
      it "strips the query and drops what is not recognised" do
        contract =
          described_class.new(
            query: "  password reset  ",
            scope: "",
            trigger: "shout",
            trigger_reason: "Not A Reason!",
            intent_heuristic: "maybe",
          )

        contract.valid?

        expect(contract).to have_attributes(
          query: "password reset",
          scope: nil,
          trigger: "",
          trigger_reason: "",
          intent_heuristic: "",
        )
      end

      it "keeps recognised values" do
        attributes = {
          query: "password reset",
          scope: "topic:12",
          trigger: "enter",
          trigger_reason: "typed:pause",
          intent_heuristic: "answer",
        }
        contract = described_class.new(**attributes)

        contract.valid?

        expect(contract).to have_attributes(attributes)
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:group)
    fab!(:user) { Fabricate(:user).tap { |member| group.add(member) } }
    fab!(:llm_model)
    fab!(:ai_agent) do
      Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
    end
    fab!(:decision_model)
    fab!(:topic)

    let(:params) do
      {
        query:,
        request_id:,
        scope:,
        classify_intent:,
        trigger: "enter",
        trigger_reason: "typed",
        intent_heuristic: "answer",
      }
    end
    let(:dependencies) { { guardian: user.guardian } }
    let(:query) { "How do I reset my password?" }
    let(:request_id) { SecureRandom.uuid }
    let(:scope) { nil }
    let(:classify_intent) { false }
    let(:ask_log) { AskAiLog.find_by(user:, query:) }

    before do
      enable_current_plugin
      SiteSetting.ai_ask_ai_enabled = true
      SiteSetting.ai_ask_ai_agent = ai_agent.id
      SiteSetting.ai_ask_ai_allowed_groups = group.id.to_s
      SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id
      SiteSetting.enable_ai_combined_search = true
      Discourse.cache.delete("discourse-ai:discoveries:prefers-results:#{user.id}")
    end

    context "when the contract is invalid" do
      let(:query) { " " }

      it { is_expected.to fail_a_contract }
    end

    context "when the user cannot ask AI" do
      fab!(:user)

      it { is_expected.to fail_a_policy(:can_ask_ai) }
    end

    context "when the request id was already used for another query" do
      before do
        DiscourseAi::Discoveries.bind_request(
          user_id: user.id,
          request_id:,
          query: "Something else entirely",
        )
      end

      it { is_expected.to fail_a_policy(:request_id_matches_query) }
    end

    context "when the request is a repeat" do
      before { DiscourseAi::Discoveries.bind_request(user_id: user.id, request_id:, query:) }

      it { is_expected.to run_successfully }

      it "does not log another ask" do
        expect { result }.not_to change { AskAiLog.count }
      end

      it "does not queue another answer" do
        expect_not_enqueued_with(job: :stream_discover_reply) { result }
      end

      it "still remembers the ask" do
        result
        expect(DiscourseAi::Discoveries.recent_asks(user_id: user.id)).to contain_exactly(
          include(term: query),
        )
      end
    end

    context "when the scoped search is judged to be about the site" do
      let(:scope) { "topic:#{topic.id}" }
      let(:classify_intent) { true }

      around do |example|
        DiscourseAi::Decisions.with_canned_answers(
          intent: "answer",
          scope: {
            "here" => 0.1,
            "site" => 0.9,
          },
        ) { example.run }
      end

      it { is_expected.to run_successfully }

      it "answers from the whole site" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            request_id:,
            scope: nil,
          },
        ) { result }
      end

      it "logs the judgement beside the scope it was made in" do
        result
        expect(ask_log).to have_attributes(
          ask_scope: scope,
          ask_intent_model: "answer",
          ask_intent_probability: 1.0,
          ask_scope_model: "site",
          ask_scope_probability: 0.9,
        )
      end
    end

    context "when the scoped search is judged to be about where it was made" do
      let(:scope) { "topic:#{topic.id}" }
      let(:classify_intent) { true }

      around do |example|
        DiscourseAi::Decisions.with_canned_answers(
          intent: "lookup",
          scope: {
            "here" => 0.8,
            "site" => 0.2,
          },
        ) { example.run }
      end

      it { is_expected.to run_successfully }

      it "answers from within the scope" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            request_id:,
            scope:,
          },
        ) { result }
      end

      it "logs the judgement" do
        result
        expect(ask_log).to have_attributes(
          ask_scope: scope,
          ask_intent_model: "lookup",
          ask_scope_model: "here",
          ask_scope_probability: 0.8,
        )
      end
    end

    context "when the scoped search is not judged" do
      let(:scope) { "topic:#{topic.id}" }

      it { is_expected.to run_successfully }

      it "answers from within the scope" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            request_id:,
            scope:,
          },
        ) { result }
      end

      it "logs the scope without verdicts" do
        result
        expect(ask_log).to have_attributes(
          ask_scope: scope,
          ask_intent_model: "",
          ask_scope_model: "",
        )
      end
    end

    context "when the site-wide search is judged" do
      let(:classify_intent) { true }

      around do |example|
        DiscourseAi::Decisions.with_canned_answers(intent: { "answer" => 0.3, "lookup" => 0.7 }) do
          example.run
        end
      end

      it { is_expected.to run_successfully }

      it "answers from the whole site" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            request_id:,
            scope: nil,
          },
        ) { result }
      end

      it "logs the intent judgement" do
        result
        expect(ask_log).to have_attributes(
          ask_scope: "",
          ask_intent_model: "lookup",
          ask_intent_probability: 0.7,
          ask_scope_model: "",
        )
      end

      it "returns the judgement" do
        expect(result[:judgement]).to have_attributes(intent: "lookup", probability: 0.7)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "logs the ask with what set it off" do
        expect { result }.to change { AskAiLog.where(user:).count }.by(1)
        expect(ask_log).to have_attributes(
          ask_trigger: "enter",
          ask_trigger_reason: "typed",
          ask_intent_heuristic: "answer",
        )
      end

      it "queues the answer" do
        expect_enqueued_with(
          job: :stream_discover_reply,
          args: {
            user_id: user.id,
            query:,
            request_id:,
            scope: nil,
          },
        ) { result }
        expect(Jobs::StreamDiscoverReply.jobs.last["args"].first).to include(
          "ask_ai_log_id" => ask_log.id,
        )
      end

      it "does not judge the search" do
        expect(result[:judgement]).to be_nil
      end

      it "leaves the judgement unlogged" do
        result
        expect(ask_log).to have_attributes(ask_scope: "", ask_intent_model: "")
      end

      it "remembers the ask" do
        expect { result }.to change { DiscourseAi::Discoveries.recent_asks(user_id: user.id) }.from(
          [],
        ).to(contain_exactly(include(term: query)))
      end

      it "returns the ask log" do
        expect(result[:ask_log]).to eq(ask_log)
      end

      it "reports the reader has no preference for results" do
        expect(result[:prefers_results]).to eq(false)
      end
    end

    context "when the reader prefers results" do
      before do
        4.times do
          AskAiLog.create!(
            user:,
            query: "Earlier question",
            asked_at: 1.day.ago,
            ask_tab_opened: "ask",
            ask_tab_switched_to: "topics",
            ask_tab_switched_after_ms: 2000,
          )
        end
      end

      it "reports the preference" do
        expect(result[:prefers_results]).to eq(true)
      end
    end

    context "when the reader prefers results without the combined search" do
      before do
        SiteSetting.enable_ai_combined_search = false
        4.times do
          AskAiLog.create!(
            user:,
            query: "Earlier question",
            asked_at: 1.day.ago,
            ask_tab_opened: "ask",
            ask_tab_switched_to: "topics",
            ask_tab_switched_after_ms: 2000,
          )
        end
      end

      it "does not report the preference" do
        expect(result[:prefers_results]).to eq(false)
      end
    end
  end
end

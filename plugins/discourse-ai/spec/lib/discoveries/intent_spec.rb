# frozen_string_literal: true

RSpec.describe DiscourseAi::Discoveries::Intent do
  fab!(:user)
  fab!(:decision_model)

  before { enable_current_plugin }

  describe ".decision_model" do
    it "is the model chosen in settings" do
      SiteSetting.ai_ask_ai_search_intent_decision_model = decision_model.id

      expect(described_class.decision_model).to eq(decision_model)
    end

    it "is nil when none is chosen" do
      expect(described_class.decision_model).to be_nil
    end
  end

  describe "#call" do
    subject(:intent) { described_class.new(user:, decision_model:) }

    it "returns the model's choice and its probability" do
      DiscourseAi::Decisions.with_canned_answers(
        intent: {
          "answer" => 0.8,
          "lookup" => 0.2,
        },
      ) do |canned|
        expect(intent.call("how do I reset my password").as_json).to eq(
          intent: "answer",
          probability: 0.8,
        )
        expect(canned.calls.sole).to include(
          state: {
            query: "how do I reset my password",
          },
          feature_name: "ai_search_intent",
          user:,
        )
      end
    end

    context "when searching in a topic or category" do
      fab!(:category) { Fabricate(:category, name: "Self-hosting") }
      fab!(:topic) { Fabricate(:topic, category:, title: "Upgrading to PostgreSQL 18") }

      it "also asks whether the search is about that place, naming it" do
        DiscourseAi::Decisions.with_canned_answers(
          intent: "answer",
          scope: {
            "here" => 0.2,
            "site" => 0.8,
          },
        ) do |canned|
          expect(intent.call("install discourse", scope: "topic:#{topic.id}").as_json).to eq(
            intent: "answer",
            probability: 1.0,
            scope: "site",
            scope_probability: 0.8,
          )
          expect(canned.calls.sole[:state]).to eq(
            query: "install discourse",
            searching_in: {
              type: "topic",
              title: topic.title,
            },
          )
        end
      end

      it "names a category by its name" do
        DiscourseAi::Decisions.with_canned_answers(intent: "lookup", scope: "here") do |canned|
          intent.call("backups", scope: "category:#{category.id}")

          expect(canned.calls.sole[:state][:searching_in]).to eq(
            type: "category",
            name: "Self-hosting",
          )
        end
      end

      it "keeps one verdict when the other is refused" do
        DiscourseAi::Decisions.with_canned_answers(intent: :refusal, scope: "here") do
          expect(intent.call("backups", scope: "topic:#{topic.id}").as_json).to eq(
            scope: "here",
            scope_probability: 1.0,
          )
        end
      end

      it "leaves out personal messages and places the reader cannot see" do
        message = Fabricate(:private_message_topic, user:)
        hidden = Fabricate(:private_category, group: Fabricate(:group))

        DiscourseAi::Decisions.with_canned_answers(intent: "lookup") do |canned|
          intent.call("notes", scope: "topic:#{message.id}")
          intent.call("notes", scope: "category:#{hidden.id}")

          expect(canned.calls.map { |call| call[:state] }).to all(eq(query: "notes"))
          expect(canned.calls.map { |call| call[:questions].map(&:name) }).to all(eq(["intent"]))
        end
      end
    end

    it "returns nil when the model refuses" do
      DiscourseAi::Decisions.with_canned_answers(intent: :refusal) do
        expect(intent.call("password")).to be_nil
      end
    end

    it "returns nil without a decision model" do
      expect(described_class.new(user:, decision_model: nil).call("password")).to be_nil
    end

    it "returns nil when the request fails" do
      stub_request(:post, decision_model.url).to_return(status: 500, body: "")

      expect(intent.call("password")).to be_nil
    end
  end
end

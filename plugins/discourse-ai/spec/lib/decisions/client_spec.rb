# frozen_string_literal: true

RSpec.describe DiscourseAi::Decisions::Client do
  fab!(:user)

  let(:questions) do
    [
      { type: "yes_no", name: "urgent", instructions: "Does this convey urgency?" },
      {
        type: "choice",
        name: "team",
        instructions: "Which team should handle this?",
        choices: [{ value: "billing", description: "Payments and invoices" }, { value: "returns" }],
      },
      {
        type: "score",
        name: "severity",
        instructions: "How severe is the problem?",
        levels: [
          { label: "low", description: "Minor annoyance" },
          { label: "medium", description: "Blocks some work" },
          { label: "high" },
        ],
      },
    ]
  end

  let(:state) { "Help! My payouts have been failing for 3 days." }

  before { enable_current_plugin }

  describe "#decide" do
    context "with a System One model" do
      fab!(:decision_model)

      let(:response_body) do
        {
          model: "jev-1.13.0",
          answers: {
            urgent: {
              type: "noul",
              noul: 0.95,
            },
            team: {
              type: "choice",
              choice: "billing",
              probabilities: {
                billing: 0.9,
                returns: 0.1,
              },
              confidence: 0.8,
            },
            severity: {
              type: "score",
              score: 1.7,
              probabilities: {
                "0" => 0.1,
                "1" => 0.1,
                "2" => 0.8,
              },
              confidence: 0.7,
              legend: {
                "0" => "Minor annoyance",
                "1" => "Blocks some work",
                "2" => "high",
              },
            },
          },
          usage: {
            input_tokens: 296,
            output_tokens: 0,
          },
        }
      end

      it "sends typed questions and returns typed answers" do
        request =
          stub_request(:post, decision_model.url).with(
            headers: {
              "Authorization" => "Bearer #{decision_model.ai_secret.secret}",
            },
            body: {
              model: "jev-latest",
              state: state,
              questions: {
                urgent: {
                  type: "noul",
                  instructions: "Does this convey urgency?",
                },
                team: {
                  type: "choice",
                  instructions: "Which team should handle this?",
                  criteria: {
                    billing: "Payments and invoices",
                    returns: nil,
                  },
                },
                severity: {
                  type: "score",
                  instructions: "How severe is the problem?",
                  criteria: ["Minor annoyance", "Blocks some work", "high"],
                },
              },
            }.to_json,
          ).to_return(status: 200, body: response_body.to_json)

        result = decision_model.decide(state, questions:, feature_name: "test")

        expect(request).to have_been_requested
        expect(result.to_h[:answers]).to eq(
          "urgent" => {
            type: "yes_no",
            probability: 0.95,
            yes: true,
          },
          "team" => {
            type: "choice",
            choice: "billing",
            probabilities: {
              "billing" => 0.9,
              "returns" => 0.1,
            },
            confidence: 0.8,
          },
          "severity" => {
            type: "score",
            score: 1.7,
            level: "high",
            probabilities: {
              "low" => 0.1,
              "medium" => 0.1,
              "high" => 0.8,
            },
            confidence: 0.7,
          },
        )
      end

      it "records the call in the audit log" do
        stub_request(:post, decision_model.url).to_return(status: 200, body: response_body.to_json)

        result =
          decision_model.decide(
            state,
            questions:,
            user:,
            feature_name: "workflows",
            feature_context: {
              workflow_id: 1,
            },
          )

        expect(AiApiAuditLog.find(result.audit_log_id)).to have_attributes(
          provider_id: AiApiAuditLog::Provider::SystemOne,
          user_id: user.id,
          feature_name: "workflows",
          feature_context: {
            "workflow_id" => 1,
          },
          language_model: "jev-latest",
          request_tokens: 296,
          response_tokens: 0,
          response_status: 200,
        )
      end

      it "omits the authorization header when no credential is set" do
        decision_model.update!(ai_secret: nil)
        stub_request(:post, decision_model.url).to_return(status: 200, body: response_body.to_json)

        decision_model.decide(state, questions:, feature_name: "test")

        expect(
          a_request(:post, decision_model.url).with { |req| !req.headers.key?("Authorization") },
        ).to have_been_made
      end

      it "returns refusals that raise when their values are read" do
        response_body[:answers][:urgent] = { type: "refusal" }
        stub_request(:post, decision_model.url).to_return(status: 200, body: response_body.to_json)

        result = decision_model.decide(state, questions:, feature_name: "test")

        expect(result.refusals.map(&:name)).to eq(["urgent"])
        expect(result).not_to be_complete
        expect { result["urgent"].yes? }.to raise_error(DiscourseAi::Decisions::Refused)
      end

      it "raises when an answer is missing or malformed" do
        response_body[:answers].delete(:urgent)
        stub_request(:post, decision_model.url).to_return(status: 200, body: response_body.to_json)

        expect { decision_model.decide(state, questions:, feature_name: "test") }.to raise_error(
          DiscourseAi::Decisions::InferenceError,
          "Malformed answer for urgent: missing",
        )
      end

      it "retries overloaded responses and network failures, recording each attempt" do
        stub_request(:post, decision_model.url)
          .to_return(status: 529, body: "")
          .then
          .to_raise(Faraday::ConnectionFailed.new("connection refused"))
          .then
          .to_return(status: 200, body: response_body.to_json)
        client = described_class.new(decision_model)
        allow(client).to receive(:sleep)

        result = client.decide(state, questions:, feature_name: "test")

        expect(result["urgent"].probability).to eq(0.95)
        expect(AiApiAuditLog.find(result.audit_log_id).request_attempts).to eq(
          [{ "status" => 529, "delay_ms" => 1000 }, { "status" => 0, "delay_ms" => 2000 }],
        )
      end

      it "raises a non-retryable error for a rejected request and logs it" do
        stub_request(:post, decision_model.url).to_return(
          status: 401,
          body: { error: { message: "Invalid API key" } }.to_json,
        )

        expect { decision_model.decide(state, questions:, feature_name: "test") }.to raise_error(
          an_instance_of(DiscourseAi::Decisions::InferenceError).and(
            having_attributes(http_status: 401, retryable?: false),
          ),
        )
        expect(AiApiAuditLog.last.response_status).to eq(401)
      end

      it "rejects invalid requests before calling the provider" do
        expect { decision_model.decide(state, questions:, feature_name: nil) }.to raise_error(
          DiscourseAi::Decisions::InvalidRequest,
          /feature_name/,
        )
        expect {
          decision_model.decide(
            state,
            questions:,
            feature_name: "test",
            images: ["data:image/png;base64,AAAA"],
          )
        }.to raise_error(DiscourseAi::Decisions::InvalidRequest, /doesn't support images/)
      end
    end

    context "with an OpenAI model" do
      fab!(:decision_model, :open_ai_decision_model)

      let(:image) { "data:image/png;base64,iVBORw0KGgo=" }

      it "sends typed questions with images and returns typed answers" do
        request =
          stub_request(:post, decision_model.url).with(
            body: {
              model: "gpt-6-luna",
              input: [
                {
                  role: "user",
                  content: [
                    { type: "input_text", text: state },
                    { type: "input_image", image_url: image },
                  ],
                },
              ],
              questions: [
                { type: "predicate", name: "urgent", instructions: "Does this convey urgency?" },
                {
                  type: "choice",
                  name: "team",
                  instructions: "Which team should handle this?",
                  choices: [
                    { value: "billing", description: "Payments and invoices" },
                    { value: "returns" },
                  ],
                },
                {
                  type: "score",
                  name: "severity",
                  instructions: "How severe is the problem?",
                  levels: [
                    { label: "low", description: "Minor annoyance" },
                    { label: "medium", description: "Blocks some work" },
                    { label: "high", description: "high" },
                  ],
                },
              ],
            }.to_json,
          ).to_return(
            status: 200,
            body: {
              model: "gpt-6-luna",
              answers: [
                { type: "predicate", name: "urgent", probability: 0.2 },
                {
                  type: "choice",
                  name: "team",
                  choice: "returns",
                  probabilities: [
                    { value: "billing", probability: 0.3 },
                    { value: "returns", probability: 0.7 },
                  ],
                  confidence: 0.6,
                },
                {
                  type: "score",
                  name: "severity",
                  score: 0.1,
                  probabilities: [
                    { value: 0, label: "low", probability: 0.9 },
                    { value: 1, label: "medium", probability: 0.1 },
                    { value: 2, label: "high", probability: 0.0 },
                  ],
                  confidence: 0.85,
                },
              ],
            }.to_json,
          )

        result = decision_model.decide(state, questions:, images: [image], feature_name: "test")

        expect(request).to have_been_requested
        expect(result["urgent"]).to have_attributes(probability: 0.2, yes?: false)
        expect(result["team"]).to have_attributes(
          choice: "returns",
          probabilities: {
            "billing" => 0.3,
            "returns" => 0.7,
          },
          confidence: 0.6,
        )
        expect(result["severity"]).to have_attributes(
          score: 0.1,
          level: "low",
          probabilities: {
            "low" => 0.9,
            "medium" => 0.1,
            "high" => 0.0,
          },
        )
        expect(AiApiAuditLog.find(result.audit_log_id).raw_request_payload).not_to include(image)
      end
    end
  end
end

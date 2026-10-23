# frozen_string_literal: true

RSpec.describe DiscourseAi::AdminDashboard::AskAiReportGenerator do
  fab!(:admin)
  fab!(:llm_model)

  let(:ask) do
    AskAiLog.create!(user: admin, query: "How do I configure email?", asked_at: Time.current)
  end
  let(:other_ask) do
    AskAiLog.create!(user: admin, query: "How do I restore a backup?", asked_at: Time.current)
  end
  let(:report) do
    AskAiReport.new(
      requested_by: admin,
      start_date: Date.current,
      end_date: Date.current,
      selected_ask_ids: [ask.id, other_ask.id],
      reported_ask_count: 2,
      total_ask_count: 2,
    )
  end
  let(:output) do
    {
      "summary" => "Members ask about email setup.",
      "subjects" => [
        { "name" => "Email", "description" => "Setting up email.", "ask_ids" => [ask.id] },
      ],
      "insights" => [
        {
          "title" => "Email setup guidance",
          "observation" => "A question asks how to configure email.",
          "suggested_action" => "Review the email setup guide.",
          "ask_ids" => [ask.id],
        },
      ],
    }
  end

  before do
    enable_current_plugin
    allow(SiteSetting).to receive(:ai_default_llm_model).and_return(llm_model.id)
  end

  def stub_open_ai_stream(*partials)
    body =
      partials
        .map { |partial| "data: #{{ choices: [{ delta: { content: partial } }] }.to_json}\n\n" }
        .join
    body << "data: [DONE]\n\n"

    stub_request(:post, llm_model.url)
      .with { |request| JSON.parse(request.body)["stream"] == true }
      .to_return(status: 200, body:, headers: { "Content-Type" => "text/event-stream" })
  end

  describe "#generate" do
    it "streams structured JSON and validates the complete report before filling missing subjects" do
      output["subjects"][0]["ask_ids"] << other_ask.id + 1
      json = output.to_json
      request = stub_open_ai_stream(json.first(35), json[35...-1], json.last)

      result = described_class.new(report).generate

      expect(request).to have_been_requested.once
      expect(result).to eq(
        output.merge(
          "subjects" => [
            { "name" => "Email", "description" => "Setting up email.", "ask_ids" => [ask.id] },
            {
              "name" => I18n.t("discourse_ai.ask_ai_reports.ungrouped_name"),
              "description" => I18n.t("discourse_ai.ask_ai_reports.ungrouped_description"),
              "ask_ids" => [other_ask.id],
            },
          ],
          "examples" => {
            ask.id => ask.query,
            other_ask.id => other_ask.query,
          },
        ),
      )
    end

    it "uses the model capacity instead of a fixed 8000-token reservation" do
      llm_model.update!(max_prompt_tokens: 6000, max_output_tokens: 1000)
      request = stub_open_ai_stream(output.to_json)

      result = described_class.new(report).generate

      expect(result).to include(output.slice("summary", "insights"))
      expect(request).to have_been_requested.once
    end

    it "rejects malformed JSON instead of accepting a partial structured response" do
      request = stub_open_ai_stream(output.to_json[0...-1])

      expect { described_class.new(report).generate }.to raise_error(JSON::ParserError)
      expect(request).to have_been_requested.once
    end

    it "rejects invalid report fields after streaming completes" do
      output["summary"] = ""
      request = stub_open_ai_stream(output.to_json)

      expect { described_class.new(report).generate }.to raise_error(
        described_class::InvalidAnalysis,
      )
      expect(request).to have_been_requested.once
    end

    it "rejects insight evidence outside the selected asks after streaming completes" do
      output["insights"][0]["ask_ids"] = [other_ask.id + 1]
      request = stub_open_ai_stream(output.to_json)

      expect { described_class.new(report).generate }.to raise_error(
        described_class::InvalidAnalysis,
        "Insight evidence must reference 1 to 3 distinct supplied IDs",
      )
      expect(request).to have_been_requested.once
    end

    it "collects string deltas beyond 8000 tokens when the agent has no structured properties" do
      llm_model.update!(max_prompt_tokens: 32_000, max_output_tokens: 16_000)
      agent = Fabricate(:ai_agent, default_llm_id: llm_model.id, response_format: [])
      SiteSetting.ai_ask_ai_report_agent = agent.id
      json = output.to_json[0...-1] + " \n" * 18_000 + "}"
      expect(llm_model.to_llm.tokenizer.size(json)).to be > 8000
      request = stub_open_ai_stream(json.first(35), json[35..])

      result = described_class.new(report).generate

      expect(request).to have_been_requested.once
      expect(result).to include(output.slice("summary", "insights"))
      expect(result["subjects"].first).to eq(output["subjects"].first)
    end

    it "retains the opening brace supplied by structured output prefilling" do
      model =
        Fabricate(:anthropic_model, provider_params: { disable_native_structured_output: true })
      allow(SiteSetting).to receive(:ai_default_llm_model).and_return(model.id)
      json = output.to_json[1..]
      events = [
        {
          type: "message_start",
          message: {
            id: "msg_report",
            type: "message",
            role: "assistant",
            content: [],
            model: model.name,
            usage: {
              input_tokens: 25,
              output_tokens: 1,
            },
          },
        },
        { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } },
        {
          type: "content_block_delta",
          index: 0,
          delta: {
            type: "text_delta",
            text: json.first(35),
          },
        },
        { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: json[35..] } },
        { type: "content_block_stop", index: 0 },
        {
          type: "message_delta",
          delta: {
            stop_reason: "end_turn",
            stop_sequence: nil,
          },
          usage: {
            output_tokens: 100,
          },
        },
        { type: "message_stop" },
      ]
      body = events.map { |event| "event: #{event[:type]}\ndata: #{event.to_json}\n\n" }.join
      request =
        stub_request(:post, model.url)
          .with do |http_request|
            payload = JSON.parse(http_request.body)
            payload["stream"] == true &&
              payload["messages"].last == { "role" => "assistant", "content" => "{" }
          end
          .to_return(status: 200, body:, headers: { "Content-Type" => "text/event-stream" })

      result = described_class.new(report).generate

      expect(request).to have_been_requested.once
      expect(result).to include(output.slice("summary", "insights"))
      expect(result["subjects"].first).to eq(output["subjects"].first)
    end
  end
end

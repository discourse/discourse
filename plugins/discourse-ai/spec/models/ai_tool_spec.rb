# frozen_string_literal: true

RSpec.describe AiTool do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  fab!(:bot_user) { Discourse.system_user }

  def create_tool(
    parameters: nil,
    script: nil,
    secret_contracts: nil,
    rag_chunk_tokens: nil,
    rag_chunk_overlap_tokens: nil
  )
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters:
        parameters || [{ name: "query", type: "string", description: "perform a search" }],
      script: script || "function invoke(params) { return params; }",
      secret_contracts: secret_contracts || [],
      created_by_id: 1,
      summary: "Test tool summary",
      rag_chunk_tokens: rag_chunk_tokens || 374,
      rag_chunk_overlap_tokens: rag_chunk_overlap_tokens || 10,
    )
  end

  before { enable_current_plugin }

  it "runs a basic tool" do
    tool = create_tool

    expect(tool.signature).to eq(
      {
        name: tool.tool_name,
        description: "test",
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
      },
    )

    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    expect(runner.invoke).to eq("query" => "test")
  end

  it "validates secret contracts" do
    tool =
      create_tool(
        parameters: [{ name: "query", type: "string", description: "perform a search" }],
        script: "function invoke(params) { return params; }",
      )

    tool.secret_contracts = [{ alias: "invalid alias" }, { alias: "invalid alias" }]

    expect(tool).not_to be_valid
    expect(tool.errors[:secret_contracts]).to be_present
  end

  it "can replace and resolve secret bindings by alias" do
    tool = create_tool(secret_contracts: [{ alias: "weather_api_key" }])
    secret = Fabricate(:ai_secret)

    tool.replace_secret_bindings!([{ alias: "weather_api_key", ai_secret_id: secret.id }])

    value, error = tool.resolve_secret("weather_api_key")
    expect(error).to be_nil
    expect(value).to eq(secret.secret)
    expect(tool.missing_secret_aliases).to eq([])
  end

  it "can timeout slow JS" do
    script = <<~JS
      function invoke(params) {
        while (true) {}
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

    runner.timeout = 5

    result = runner.invoke
    expect(result[:error]).to eq("Script terminated due to timeout")
  end

  it "can use sleep function with limits" do
    script = <<~JS
      function invoke(params) {
        let results = [];
        for (let i = 0; i < 3; i++) {
          let result = sleep(1); // 1ms sleep
          results.push(result);
        }
        return results;
      }
    JS

    tool = create_tool(script: script)
    runner = tool.runner({}, llm: nil, bot_user: nil)

    result = runner.invoke

    expect(result).to eq([{ "slept" => 1 }, { "slept" => 1 }, { "slept" => 1 }])
  end

  it "runs the fxmacrodata preset" do
    preset = AiTool.presets.find { |p| p[:preset_id] == "fxmacrodata" }
    tool = create_tool(parameters: preset[:parameters], script: preset[:script])
    base_url = "https://api.fxmacrodata.com/v1"

    stub_request(:get, "#{base_url}/announcements/usd/inflation?limit=2").to_return(
      status: 200,
      body: {
        currency: "USD",
        indicator: "inflation",
        name: "Inflation (CPI)",
        source: "BLS",
        value_metadata: {
          source_unit: "%YoY",
        },
        freemium_delay: {
          applied: true,
          withheld_count: 0,
          message: "Free access is delayed by 15 minutes.",
        },
        data: [
          {
            date: "2026-08-31",
            val: 3.4,
            announcement_datetime_local: "2026-09-11T08:30:00-04:00",
          },
        ],
      }.to_json,
    )

    stub_request(:get, "#{base_url}/calendar/usd?indicator=inflation").to_return(
      status: 200,
      body: {
        data: [
          {
            announcement_datetime_utc: "2026-10-14T12:30:00+00:00",
            reference_period: "September 2026",
          },
        ],
      }.to_json,
    )

    runner = tool.runner({ "indicator" => "inflation", "limit" => 2 }, llm: nil, bot_user: nil)
    result = runner.invoke

    expect(result["unit"]).to eq("%YoY")
    expect(result["observations"]).to eq(
      [{ "date" => "2026-08-31", "value" => 3.4, "released_at" => "2026-09-11T08:30:00-04:00" }],
    )
    expect(result["freemium_delay"]["withheld_count"]).to eq(0)
    expect(result["next_release"]["scheduled_at"]).to eq("2026-10-14T12:30:00+00:00")
  end

  it "returns an error when the fxmacrodata preset gets an error body with a 200" do
    preset = AiTool.presets.find { |p| p[:preset_id] == "fxmacrodata" }
    tool = create_tool(parameters: preset[:parameters], script: preset[:script])
    base_url = "https://api.fxmacrodata.com/v1"

    stub_request(:get, "#{base_url}/announcements/usd/inflation?limit=5").to_return(
      status: 200,
      body: { detail: "Unknown indicator" }.to_json,
    )

    runner = tool.runner({ "indicator" => "inflation" }, llm: nil, bot_user: nil)
    result = runner.invoke

    expect(result["error"]).to eq("Unknown indicator")
  end

  describe "#set_image_generation_tool_flag" do
    it "sets flag to true when tool has all required characteristics" do
      tool =
        create_tool(parameters: [{ name: "prompt", type: "string", required: true }], script: <<~JS)
            function invoke(params) {
              const image = upload.create("test.png", "base64data");
              chain.setCustomRaw(`![test](${image.short_url})`);
              return { result: "success" };
            }
          JS

      expect(tool.is_image_generation_tool).to eq(true)
    end

    it "sets flag to false when tool missing prompt parameter" do
      tool =
        create_tool(parameters: [{ name: "query", type: "string", required: true }], script: <<~JS)
            function invoke(params) {
              const image = upload.create("test.png", "base64data");
              chain.setCustomRaw(`![test](${image.short_url})`);
              return { result: "success" };
            }
          JS

      expect(tool.is_image_generation_tool).to eq(false)
    end

    it "sets flag to false when tool missing upload.create" do
      tool =
        create_tool(parameters: [{ name: "prompt", type: "string", required: true }], script: <<~JS)
            function invoke(params) {
              chain.setCustomRaw(`![test](upload://test123)`);
              return { result: "success" };
            }
          JS

      expect(tool.is_image_generation_tool).to eq(false)
    end

    it "sets flag to false when tool missing chain.setCustomRaw" do
      tool =
        create_tool(parameters: [{ name: "prompt", type: "string", required: true }], script: <<~JS)
            function invoke(params) {
              const image = upload.create("test.png", "base64data");
              return { result: "success", image: image };
            }
          JS

      expect(tool.is_image_generation_tool).to eq(false)
    end

    it "updates flag when tool is updated" do
      tool =
        create_tool(
          parameters: [{ name: "query", type: "string", required: true }],
          script: "function invoke(params) { return params; }",
        )

      expect(tool.is_image_generation_tool).to eq(false)

      tool.update!(parameters: [{ name: "prompt", type: "string", required: true }], script: <<~JS)
          function invoke(params) {
            const image = upload.create("test.png", "base64data");
            chain.setCustomRaw(`![test](${image.short_url})`);
            return { result: "success" };
          }
        JS

      expect(tool.is_image_generation_tool).to eq(true)
    end

    it "handles edge case with spaces in method calls" do
      tool =
        create_tool(parameters: [{ name: "prompt", type: "string", required: true }], script: <<~JS)
            function invoke(params) {
              const image = upload . create("test.png", "base64data");
              chain . setCustomRaw(`![test](${image.short_url})`);
              return { result: "success" };
            }
          JS

      expect(tool.is_image_generation_tool).to eq(false)
    end
  end
end

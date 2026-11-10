# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Classify::V1 do
  fab!(:decision_model) { Fabricate(:decision_model, display_name: "Workflow decisions") }

  let(:spam_question) do
    { "name" => "is_spam", "type" => "yes_no", "instructions" => "Is this post spam?" }
  end
  let(:team_question) do
    {
      "name" => "team",
      "type" => "choice",
      "instructions" => "Which team?",
      "choices" => %w[billing returns],
    }
  end
  let(:score_question) do
    {
      "name" => "severity",
      "type" => "score",
      "instructions" => "How bad?",
      "levels" => %w[low high],
    }
  end

  before { enable_current_plugin }

  def configuration(*questions, **overrides)
    {
      "decision_model_id" => decision_model.id,
      "text" => "={{ $json.post.raw }}",
      "questions" => {
        "values" => questions,
      },
    }.merge(overrides.stringify_keys)
  end

  def post_item(raw)
    { "json" => { "post" => { "raw" => raw } } }
  end

  it "passes the framework's property schema validation" do
    expect(
      DiscourseWorkflows::PropertySchemaValidator.call(
        "action:classify",
        described_class.property_schema,
      ),
    ).to be_empty
  end

  describe ".available?" do
    it "requires the AI plugin and a decision model" do
      expect(described_class.available?).to eq(true)
      SiteSetting.discourse_ai_enabled = false
      expect(described_class.available?).to eq(false)
      SiteSetting.discourse_ai_enabled = true
      DecisionModel.delete_all
      expect(described_class.available?).to eq(false)
    end
  end

  describe ".load_options_context" do
    it "lists decision models matching the filter" do
      Fabricate(:decision_model, display_name: "Another one")
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "decision_models",
          filter: "Workflow",
        )
      expect(described_class.load_options_context(context)).to eq(
        [{ id: decision_model.id, name: "Workflow decisions" }],
      )
    end
  end

  describe "#execute" do
    it "adds typed answers to each item and matches the resolved output schema" do
      config = configuration(spam_question, team_question, score_question)
      DiscourseAi::Decisions.with_canned_answers(
        is_spam: 0.95,
        team: "billing",
        severity: {
          "low" => 0.25,
          "high" => 0.75,
        },
      ) do |canned|
        items =
          execute_node_output(
            configuration: config,
            input_items: [post_item("Buy now!"), post_item("Hello!")],
          ).first
        expected = {
          "is_spam" => {
            "type" => "yes_no",
            "probability" => 0.95,
          },
          "team" => {
            "type" => "choice",
            "choice" => "billing",
            "probabilities" => {
              "billing" => 1.0,
              "returns" => 0.0,
            },
            "confidence" => 1.0,
          },
          "severity" => {
            "type" => "score",
            "score" => 0.75,
            "level" => "high",
            "probabilities" => {
              "low" => 0.25,
              "high" => 0.75,
            },
            "confidence" => 0.75,
          },
        }
        expect(items.map { |item| item.dig("json", "classification") }).to eq([expected, expected])
        expect(items.first.dig("json", "post", "raw")).to eq("Buy now!")
        expect(items.first["json"]).to match_node_output_schema(
          described_class,
          configuration: config,
        )
        expect(canned.calls.map { |call| call[:state] }).to eq(["Buy now!", "Hello!"])
        expect(canned.calls.map { |call| call[:feature_name] }.uniq).to eq(["workflow"])
        expect(canned.calls.map { |call| call[:user] }.uniq).to eq([Discourse.system_user])
      end
    end

    it "keeps refusals in the output without failing the item" do
      config = configuration(spam_question, team_question)
      DiscourseAi::Decisions.with_canned_answers(is_spam: :refusal, team: "returns") do
        item = execute_node(configuration: config, item: post_item("Hello"))
        expect(item.dig("classification", "is_spam")).to eq("type" => "refusal", "reason" => nil)
        expect(item.dig("classification", "team", "choice")).to eq("returns")
        expect(item).to match_node_output_schema(described_class, configuration: config)
      end
    end

    it "fails the item when questions are invalid" do
      expect {
        execute_node(
          configuration: configuration(team_question.merge("choices" => ["only"])),
          item: post_item("Hello"),
        )
      }.to raise_error(DiscourseWorkflows::NodeError, /Workflow decisions.*team.*choices/)

      expect {
        execute_node(configuration: configuration("not a question"), item: post_item("Hello"))
      }.to raise_error(DiscourseWorkflows::NodeError, /Questions must be hashes/)
    end

    it "names the decision model in provider failures" do
      request =
        stub_request(:post, decision_model.url).to_return(
          status: 401,
          body: { message: "Rejected" }.to_json,
        )
      expect {
        execute_node(configuration: configuration(spam_question), item: post_item("Hello"))
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Decision model 'Workflow decisions' could not answer: Request failed with status 401: Rejected [item 0]",
      )
      expect(request).to have_been_requested.once
    end

    it "sends image uploads to a vision-enabled model" do
      decision_model.update!(
        vision_enabled: true,
        custom_headers: [{ name: "X-Image-Input", value: "true" }],
      )
      upload = Fabricate(:image_upload)
      request =
        stub_request(:post, decision_model.url)
          .with(headers: { "X-Image-Input" => "true" }) do |req|
            payload = JSON.parse(req.body)
            image = payload.fetch("images").sole
            payload.fetch("state") == "Lunch" && !payload.key?("assets") &&
              image.start_with?("data:image/png;base64,") &&
              Base64.strict_decode64(image.split(",", 2).last).start_with?("\x89PNG".b)
          end
          .to_return(body: { answers: { is_hotdog: { type: "noul", noul: 0.97 } } }.to_json)
      config =
        configuration(
          { "name" => "is_hotdog", "type" => "yes_no", "instructions" => "Is this a hot dog?" },
          upload_ids: "={{ $json.post.upload_ids }}",
        )
      item =
        execute_node(
          configuration: config,
          item: {
            "json" => {
              "post" => {
                "raw" => "Lunch",
                "upload_ids" => "[#{upload.id}, #{upload.id}]",
              },
            },
          },
        )
      expect(request).to have_been_requested.once
      expect(item.dig("classification", "is_hotdog", "probability")).to eq(0.97)
      expect(item).to match_node_output_schema(described_class, configuration: config)
    end

    it "fails instead of answering when an image can't be sent" do
      decision_model.update!(vision_enabled: true)
      upload = Fabricate(:image_upload, original_filename: "cube.png")
      missing_id = upload.id + 1000
      allow(DiscourseAi::Completions::UploadEncoder).to receive(:fetch_path).and_return(nil)
      request = stub_request(:post, decision_model.url)

      expect {
        execute_node(
          configuration:
            configuration(
              { "name" => "solved", "type" => "yes_no", "instructions" => "Is the cube solved?" },
              upload_ids: "={{ $json.post.upload_ids }}",
            ),
          item: {
            "json" => {
              "post" => {
                "raw" => "Done!",
                "upload_ids" => [upload.id, missing_id],
              },
            },
          },
        )
      }.to raise_error(
        DiscourseWorkflows::NodeError,
        "Decision model 'Workflow decisions' could not answer: Upload #{missing_id} was not found. " \
          "Upload #{upload.id} (cube.png) was not sent: file is not available in the store [item 0]",
      )
      expect(request).not_to have_been_requested
    end

    it "fails when the decision model no longer exists" do
      expect {
        execute_node(
          configuration: configuration(spam_question, decision_model_id: -1),
          item: post_item("Hello"),
        )
      }.to raise_error(DiscourseWorkflows::NodeError, "Decision model with id -1 not found")
    end
  end
end

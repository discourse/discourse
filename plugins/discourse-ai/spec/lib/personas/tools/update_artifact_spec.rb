# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::UpdateArtifact do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  fab!(:post)
  fab!(:artifact) do
    AiArtifact.create!(
      user: Fabricate(:user),
      post: post,
      name: "Test Artifact",
      html: "<div>Original</div>",
      css: ".test { color: blue; }",
      js: "console.log('original');\nconsole.log('world');\nconsole.log('hello');",
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#process" do
    it "correctly updates artifact using section markers" do
      responses = [<<~TXT.strip]
        [HTML]
        <div>Updated</div>
        [/HTML]
        [CSS]
        .test { color: red; }
        [/CSS]
        [JavaScript]
        console.log('updated');
        console.log('world');
        console.log('updated2');
        [/JavaScript]
      TXT

      tool = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            {
              artifact_id: artifact.id,
              instructions: "Change the text to Updated and color to red",
            },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            persona_options: {
              "update_algorithm" => "full",
            },
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("success")
      end

      version = artifact.versions.order(:version_number).last
      expect(version.html).to eq("<div>Updated</div>")
      expect(version.css).to eq(".test { color: red; }")
      expect(version.js).to eq(<<~JS.strip)
        console.log('updated');
        console.log('world');
        console.log('updated2');
      JS

      expect(tool.custom_raw).to include("Change Description")
      expect(tool.custom_raw).to include("[details='View Changes']")
      expect(tool.custom_raw).to include("### HTML Changes")
      expect(tool.custom_raw).to include("### CSS Changes")
      expect(tool.custom_raw).to include("### JS Changes")
      expect(tool.custom_raw).to include("<div class=\"ai-artifact\"")
    end

    it "handles partial updates with only some sections" do
      responses = [<<~TXT.strip]
        [JavaScript]
        console.log('updated');
        console.log('world');
        console.log('hello');
        [/JavaScript]
      TXT

      tool = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            { artifact_id: artifact.id, instructions: "Update only JavaScript" },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            persona_options: {
              "update_algorithm" => "full",
            },
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("success")
      end

      version = artifact.versions.order(:version_number).last
      expect(version.html).to eq("<div>Original</div>")
      expect(version.css).to eq(".test { color: blue; }")
      expect(version.js).to eq(
        "console.log('updated');\nconsole.log('world');\nconsole.log('hello');",
      )
    end

    it "handles invalid section format" do
      responses = ["Invalid format without proper section markers"]

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            { artifact_id: artifact.id, instructions: "Invalid update" },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("success") # The strategy will just keep original content
      end
    end

    it "handles invalid artifact ID" do
      tool =
        described_class.new(
          { artifact_id: -1, instructions: "Update something" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq("Artifact not found")
    end

    it "preserves unchanged sections in the diff output" do
      responses = [<<~TXT.strip]
        [HTML]
        <div>Updated</div>
        [/HTML]
      TXT

      tool = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            { artifact_id: artifact.id, instructions: "Just update the HTML" },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            persona_options: {
              "update_algorithm" => "full",
            },
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )

        tool.invoke {}
      end

      version = artifact.versions.order(:version_number).last
      expect(version.css).to eq(artifact.css)
      expect(version.js).to eq(artifact.js)
      expect(tool.custom_raw).to include("### HTML Changes")
      expect(tool.custom_raw).not_to include("### CSS Changes")
      expect(tool.custom_raw).not_to include("### JavaScript Changes")
    end

    it "handles updates to specific versions" do
      # Create first version
      responses = [<<~TXT.strip]
        [HTML]
        <div>Version 1</div>
        [/HTML]
      TXT

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        described_class
          .new(
            { artifact_id: artifact.id, instructions: "Update to version 1" },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            persona_options: {
              "update_algorithm" => "full",
            },
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )
          .invoke {}
      end

      first_version = artifact.versions.order(:version_number).last

      responses = [<<~TXT.strip]
        [HTML]
        <div>Updated from version 1</div>
        [/HTML]
      TXT

      DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
        tool =
          described_class.new(
            {
              artifact_id: artifact.id,
              version: first_version.version_number,
              instructions: "Update from version 1",
            },
            bot_user: bot_user,
            llm: llm_model.to_llm,
            persona_options: {
              "update_algorithm" => "full",
            },
            context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          )

        result = tool.invoke {}
        expect(result[:status]).to eq("success")
      end

      latest_version = artifact.versions.order(:version_number).last
      expect(latest_version.html).to eq("<div>Updated from version 1</div>")
    end
  end

  it "correctly updates artifact using diff strategy (partial diff)" do
    responses = [<<~TXT.strip]

    [HTML]
    nonsense
    <<<<<<< SEARCH
    <div>Original</div>
    =======
    <div>Updated</div>
    >>>>>>> REPLACE
    garbage llm injects
    [/HTML]

    [CSS]
    garbage llm injects
    <<<<<<< SEARCH
    .test { color: blue; }
    =======
    .test { color: red; }
    >>>>>>> REPLACE
    nonsense
    [/CSS]

    [JavaScript]
    no changes
    [/JavaScript]

    LLMs like to say nonsense that we can ignore here as well
  TXT

    tool = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
      tool =
        described_class.new(
          { artifact_id: artifact.id, instructions: "Change the text to Updated and color to red" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          persona_options: {
            "update_algorithm" => "diff",
          },
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")
    end

    version = artifact.versions.order(:version_number).last
    expect(version.html).to eq("<div>Updated</div>")
    expect(version.css).to eq(".test { color: red; }")
    expect(version.js).to eq(<<~JS.strip)
    console.log('original');
    console.log('world');
    console.log('hello');
  JS

    expect(tool.custom_raw).to include("Change Description")
    expect(tool.custom_raw).to include("[details='View Changes']")
    expect(tool.custom_raw).to include("### HTML Changes")
    expect(tool.custom_raw).to include("### CSS Changes")
    expect(tool.custom_raw).to include("<div class=\"ai-artifact\"")
  end

  it "correctly updates artifact using diff strategy" do
    responses = [<<~TXT.strip]

    [HTML]
    <<<<<<< SEARCH
    <div>Original</div>
    =======
    <div>Updated</div>
    >>>>>>> REPLACE
    [/HTML]

    [CSS]
    <<<<<<< SEARCH
    .test { color: blue; }
    =======
    .test { color: red; }
    >>>>>>> REPLACE
    [/CSS]

    [JavaScript]
    <<<<<<< SEARCH
    console.log('original');
    console.log('world');
    console.log('hello');
    =======
    console.log('updated');
    console.log('world');
    console.log('updated sam');
    >>>>>>> REPLACE
    [/JavaScript]

    LLMs like to say nonsense that we can ignore here
  TXT

    tool = nil

    DiscourseAi::Completions::Llm.with_prepared_responses(responses) do
      tool =
        described_class.new(
          { artifact_id: artifact.id, instructions: "Change the text to Updated and color to red" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(messages: [], post: post),
          persona_options: {
            "update_algorithm" => "diff",
          },
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")
    end

    version = artifact.versions.order(:version_number).last
    expect(version.html).to eq("<div>Updated</div>")
    expect(version.css).to eq(".test { color: red; }")
    expect(version.js).to eq(<<~JS.strip)
    console.log('updated');
    console.log('world');
    console.log('updated sam');
  JS

    expect(tool.custom_raw).to include("Change Description")
    expect(tool.custom_raw).to include("[details='View Changes']")
    expect(tool.custom_raw).to include("### HTML Changes")
    expect(tool.custom_raw).to include("### CSS Changes")
    expect(tool.custom_raw).to include("### JS Changes")
    expect(tool.custom_raw).to include("<div class=\"ai-artifact\"")
  end
end

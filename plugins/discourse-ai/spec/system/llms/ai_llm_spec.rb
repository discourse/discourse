# frozen_string_literal: true

RSpec.describe "Managing LLM configurations", type: :system, js: true do
  fab!(:admin)

  let(:page_header) { PageObjects::Components::DPageHeader.new }
  let(:form) { PageObjects::Components::FormKit.new("form") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    sign_in(admin)
  end

  it "correctly sets defaults" do
    visit "/admin/plugins/discourse-ai/ai-llms"

    find("[data-llm-id='anthropic-claude-opus-4-0'] button").click()
    form.field("api_key").fill_in("abcd")
    form.field("enabled_chat_bot").toggle
    form.submit

    expect(page).to have_current_path(%r{/admin/plugins/discourse-ai/ai-llms/\d+/edit})

    llm = LlmModel.order(:id).last

    expect(llm.api_key).to eq("abcd")

    preset = DiscourseAi::Completions::Llm.presets.find { |p| p[:id] == "anthropic" }
    model_preset = preset[:models].find { |m| m[:name] == "claude-opus-4-0" }

    expect(llm.name).to eq("claude-opus-4-0")
    expect(llm.url).to eq(preset[:endpoint])
    expect(llm.tokenizer).to eq(preset[:tokenizer].to_s)
    expect(llm.max_prompt_tokens.to_i).to eq(model_preset[:tokens])
    expect(llm.provider).to eq("anthropic")
    expect(llm.display_name).to eq(model_preset[:display_name])
    expect(llm.user_id).not_to be_nil
  end

  it "manually configures an LLM" do
    llm_count = LlmModel.count

    visit "/admin/plugins/discourse-ai/ai-llms"

    expect(page_header).to be_visible

    find("[data-llm-id='none'] button").click()

    expect(page_header).to be_hidden

    form.field("display_name").fill_in("Self-hosted LLM")
    form.field("name").fill_in("llava-hf/llava-v1.6-mistral-7b-hf")
    form.field("url").fill_in("srv://self-hostest.test")
    form.field("api_key").fill_in("1234")
    form.field("max_prompt_tokens").fill_in(8000)
    form.field("provider").select("vllm")
    form.field("tokenizer").select("DiscourseAi::Tokenizer::Llama3Tokenizer")
    form.field("max_output_tokens").fill_in(2000)
    form.field("vision_enabled").toggle
    form.field("enabled_chat_bot").toggle
    form.submit

    expect(page).to have_current_path(%r{/admin/plugins/discourse-ai/ai-llms/\d+/edit})
    llm = LlmModel.order(:id).last
    expect(llm.max_output_tokens.to_i).to eq(2000)

    expect(page).to have_current_path("/admin/plugins/discourse-ai/ai-llms/#{llm.id}/edit")

    form.field("max_output_tokens").fill_in(2001)
    form.submit

    # should go to llm list and see the llms correctly configured
    page.go_back

    expect(page).to have_selector(".ai-llms-list-editor__configured .ai-llm-list__row", count: 1)

    llm.reload
    expect(llm.display_name).to eq("Self-hosted LLM")
    expect(llm.name).to eq("llava-hf/llava-v1.6-mistral-7b-hf")
    expect(llm.url).to eq("srv://self-hostest.test")
    expect(llm.tokenizer).to eq("DiscourseAi::Tokenizer::Llama3Tokenizer")
    expect(llm.max_prompt_tokens.to_i).to eq(8000)
    expect(llm.provider).to eq("vllm")
    expect(llm.max_output_tokens.to_i).to eq(2001)
    expect(llm.vision_enabled).to eq(true)
    expect(llm.user_id).not_to be_nil

    expect(LlmModel.count).to eq(llm_count + 1)
  end

  context "when changing the provider" do
    it "has the correct provider params when visiting the edit page" do
      llm =
        Fabricate(:llm_model, provider: "anthropic", provider_params: { enable_reasoning: true })
      visit "/admin/plugins/discourse-ai/ai-llms/#{llm.id}/edit"

      expect(form).to have_field_with_name("provider_params.disable_native_tools")
      expect(form).to have_field_with_name("provider_params.reasoning_tokens")

      reasoning = form.field("provider_params.enable_reasoning")
      expect(reasoning).to be_checked
    end
    it "correctly changes the provider params" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      find("[data-llm-id='none'] button").click()
      form.field("provider").select("vllm")

      expect(form).to have_field_with_name("provider_params.disable_system_prompt")
      expect(form).to have_no_field_with_name("provider_params.disable_native_tools")

      form.field("provider").select("open_router")

      expect(form).to have_field_with_name("provider_params.disable_streaming")
      expect(form).to have_field_with_name("provider_params.disable_native_tools")
    end

    it "updates if the url can be edited" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      find("[data-llm-id='none'] button").click()
      form.field("provider").select("vllm")

      expect(form).to have_field_with_name("url")

      form.field("provider").select("aws_bedrock")

      expect(form).to have_no_field_with_name("url")
    end
  end

  context "with quotas" do
    fab!(:llm_model_1) { Fabricate(:llm_model, name: "claude-2") }
    fab!(:group_1) { Fabricate(:group) }

    before { Fabricate(:llm_quota, group: group_1, llm_model: llm_model_1, max_tokens: 1000) }

    it "prefills the quotas form" do
      visit "/admin/plugins/discourse-ai/ai-llms/#{llm_model_1.id}/edit"

      expect(page).to have_selector(
        ".ai-llm-quotas__table .ai-llm-quotas__cell",
        text: group_1.name,
      )
    end

    it "can remove a quota" do
      visit "/admin/plugins/discourse-ai/ai-llms/#{llm_model_1.id}/edit"

      find(".ai-llm-quotas__delete-btn:nth-child(1)").click

      expect(page).to have_no_selector(
        ".ai-llm-quotas__table .ai-llm-quotas__cell",
        text: group_1.name,
      )
    end

    it "can add a quota" do
      visit "/admin/plugins/discourse-ai/ai-llms/#{llm_model_1.id}/edit"
      find(".ai-llm-editor__add-quota-btn").click
      select_kit = PageObjects::Components::SelectKit.new(".group-chooser")
      select_kit.expand
      select_kit.select_row_by_value(1)
      form = PageObjects::Components::FormKit.new(".ai-llm-quota-modal form")
      form.field("max_tokens").fill_in(2000)
      form.submit

      expect(page).to have_selector(
        ".ai-llm-quotas__table .ai-llm-quotas__cell",
        text: Group.find(1).name,
      )
    end
  end

  context "when seeded LLM is present" do
    fab!(:llm_model) { Fabricate(:seeded_model) }

    it "shows the provider as CDCK in the UI" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      expect(page).to have_css(
        "[data-llm-id='cdck-hosted']",
        text: I18n.t("js.discourse_ai.llms.providers.CDCK"),
      )
    end

    it "seeded LLM has a description" do
      visit "/admin/plugins/discourse-ai/ai-llms"

      desc = I18n.t("js.discourse_ai.llms.preseeded_model_description", model: llm_model.name)

      expect(page).to have_css(
        "[data-llm-id='#{llm_model.name}'] .ai-llm-list__description",
        text: desc,
      )
    end

    it "seeded LLM has a disabled edit button" do
      visit "/admin/plugins/discourse-ai/ai-llms"
      expect(page).to have_css("[data-llm-id='cdck-hosted'] .ai-llm-list__edit-disabled-tooltip")
    end
  end
end

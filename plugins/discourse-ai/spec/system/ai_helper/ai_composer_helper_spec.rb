# frozen_string_literal: true

RSpec.describe "AI Composer helper", type: :system do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:non_member_group, :group)
  fab!(:embedding_definition)

  before do
    enable_current_plugin
    Group.find_by(id: Group::AUTO_GROUPS[:admins]).add(user)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true
    Jobs.run_immediately!
    sign_in(user)
  end

  let(:input) { "The rain in spain stays mainly in the Plane." }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:ai_helper_menu) { PageObjects::Components::AiComposerHelperMenu.new }
  let(:diff_modal) { PageObjects::Modals::DiffModal.new }
  let(:ai_suggestion_dropdown) { PageObjects::Components::AiSuggestionDropdown.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  fab!(:category)
  fab!(:category_2, :category)
  fab!(:video, :tag)
  fab!(:music, :tag)
  fab!(:cloud, :tag)
  fab!(:feedback, :tag)
  fab!(:review, :tag)
  fab!(:topic) { Fabricate(:topic, category: category, tags: [video, music]) }
  fab!(:post) do
    Fabricate(
      :post,
      topic: topic,
      raw:
        "I like to eat pie. It is a very good dessert. Some people are wasteful by throwing pie at others but I do not do that. I always eat the pie.",
    )
  end

  def trigger_composer_helper(content)
    visit("/latest")
    page.find("#create-topic").click
    composer.fill_content(content)
    composer.click_toolbar_button("ai-helper-trigger")
  end

  context "when triggering composer AI helper" do
    it "shows the context menu when clicking the AI button in the composer toolbar" do
      trigger_composer_helper(input)
      expect(ai_helper_menu).to have_context_menu
    end

    it "shows a toast error when clicking the AI button without content" do
      trigger_composer_helper("")
      expect(ai_helper_menu).to have_no_context_menu
      expect(toasts).to have_error(I18n.t("js.discourse_ai.ai_helper.no_content_error"))
    end

    it "shows prompt options in menu when AI button is clicked" do
      trigger_composer_helper(input)
      expect(ai_helper_menu).to be_showing_options
    end

    context "when using custom prompt" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT }

      let(:custom_prompt_input) { "Translate to French" }
      let(:custom_prompt_response) { "La pluie en Espagne reste principalement dans l'avion." }

      it "shows custom prompt option" do
        trigger_composer_helper(input)
        expect(ai_helper_menu).to have_custom_prompt
      end

      it "enables the custom prompt button when input is filled" do
        trigger_composer_helper(input)
        expect(ai_helper_menu).to have_custom_prompt_button_disabled
        ai_helper_menu.fill_custom_prompt(custom_prompt_input)
        expect(ai_helper_menu).to have_custom_prompt_button_enabled
      end

      xit "replaces the composed message with AI generated content" do
        # TODO: @keegan - this is a flake
        # Failure/Error: super

        # Playwright::TimeoutError:
        # Timeout 11000ms exceeded.
        # Call log:
        # - attempting click action
        # -     2 × waiting for element to be visible, enabled and stable
        # -       - element is not enabled
        # -     - retrying click action
        # -     - waiting 20ms
        # -     2 × waiting for element to be visible, enabled and stable
        # -       - element is not enabled
        # -     - retrying click action
        # -       - waiting 100ms
        # -     21 × waiting for element to be visible, enabled and stable
        # -        - element is not enabled
        # -      - retrying click action
        # -        - waiting 500ms

        trigger_composer_helper(input)
        ai_helper_menu.fill_custom_prompt(custom_prompt_input)

        DiscourseAi::Completions::Llm.with_prepared_responses([custom_prompt_response]) do
          ai_helper_menu.click_custom_prompt_button
          diff_modal.confirm_changes
          wait_for { composer.composer_input.value == custom_prompt_response }
          expect(composer.composer_input.value).to eq(custom_prompt_response)
        end
      end
    end

    context "when not a member of custom prompt group" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::CUSTOM_PROMPT }
      before { SiteSetting.ai_helper_custom_prompts_allowed_groups = non_member_group.id.to_s }

      it "does not show custom prompt option" do
        trigger_composer_helper(input)
        expect(ai_helper_menu).to have_no_custom_prompt
      end
    end

    context "when using translation mode" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::TRANSLATE }

      let(:spanish_input) { "La lluvia en España se queda principalmente en el avión." }

      it "replaces the composed message with AI generated content" do
        trigger_composer_helper(spanish_input)

        DiscourseAi::Completions::Llm.with_prepared_responses([input]) do
          ai_helper_menu.select_helper_model(mode)
          diff_modal.confirm_changes
          wait_for { composer.composer_input.value == input }
          expect(composer.composer_input.value).to eq(input)
        end
      end

      it "reverts results when Ctrl/Cmd + Z is pressed on the keyboard" do
        trigger_composer_helper(spanish_input)

        DiscourseAi::Completions::Llm.with_prepared_responses([input]) do
          ai_helper_menu.select_helper_model(mode)
          diff_modal.confirm_changes
          wait_for { composer.composer_input.value == input }
          ai_helper_menu.press_undo_keys
          expect(composer.composer_input.value).to eq(spanish_input)
        end
      end

      it "shows the changes in a modal" do
        trigger_composer_helper(spanish_input)

        DiscourseAi::Completions::Llm.with_prepared_responses([input]) do
          ai_helper_menu.select_helper_model(mode)

          expect(diff_modal).to be_visible
          expect(diff_modal.old_value).to eq(spanish_input.gsub(/[[:space:]]+/, " ").strip)
          expect(diff_modal.new_value).to eq(
            input.gsub(/[[:space:]]+/, " ").gsub(/[‘’]/, "'").gsub(/[“”]/, '"').strip,
          )
          diff_modal.confirm_changes
          expect(ai_helper_menu).to have_no_context_menu
        end
      end

      it "does not apply the changes when discard button is pressed in the modal" do
        trigger_composer_helper(spanish_input)
        DiscourseAi::Completions::Llm.with_prepared_responses([input]) do
          ai_helper_menu.select_helper_model(mode)
          expect(diff_modal).to be_visible
          diff_modal.discard_changes
          expect(ai_helper_menu).to have_no_context_menu
          expect(composer.composer_input.value).to eq(spanish_input)
        end
      end
    end

    context "when using the proofreading mode" do
      let(:mode) { DiscourseAi::AiHelper::Assistant::PROOFREAD }

      let(:proofread_text) { "The rain in Spain, stays mainly in the Plane." }

      it "replaces the composed message with AI generated content" do
        trigger_composer_helper(input)

        DiscourseAi::Completions::Llm.with_prepared_responses([proofread_text]) do
          ai_helper_menu.select_helper_model(mode)
          diff_modal.confirm_changes
          wait_for { composer.composer_input.value == proofread_text }
          expect(composer.composer_input.value).to eq(proofread_text)
        end
      end
    end
  end

  context "when suggesting titles with AI title suggester" do
    let(:mode) { DiscourseAi::AiHelper::Assistant::GENERATE_TITLES }

    let(:titles) do
      {
        output: [
          "Rainy Spain",
          "Plane-Bound Delights",
          "Mysterious Spain",
          "Plane-Rain Chronicles",
          "Unveiling Spain",
        ],
      }
    end

    it "opens a menu with title suggestions" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
        ai_suggestion_dropdown.click_suggest_titles_button

        wait_for { ai_suggestion_dropdown.has_dropdown? }

        expect(ai_suggestion_dropdown).to have_dropdown
      end
    end

    it "replaces the topic title with the selected title" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
        ai_suggestion_dropdown.click_suggest_titles_button
        wait_for { ai_suggestion_dropdown.has_dropdown? }
        ai_suggestion_dropdown.select_suggestion_by_value(1)

        expect(page).to have_field("reply-title", with: "Plane-Bound Delights")
      end
    end

    it "closes the menu when clicking outside" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)

      DiscourseAi::Completions::Llm.with_prepared_responses([titles]) do
        ai_suggestion_dropdown.click_suggest_titles_button

        wait_for { ai_suggestion_dropdown.has_dropdown? }

        find(".d-editor-preview").click

        expect(ai_suggestion_dropdown).to have_no_dropdown
      end
    end

    it "only shows trigger button if there is sufficient content in the composer" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content("abc")

      expect(ai_suggestion_dropdown).to have_no_suggestion_button

      composer.fill_content(input)
      expect(ai_suggestion_dropdown).to have_suggestion_button
    end
  end

  context "when suggesting the category with AI category suggester" do
    before do
      SiteSetting.ai_embeddings_selected_model = embedding_definition.id
      SiteSetting.ai_embeddings_enabled = true
    end

    it "updates the category with the suggested category" do
      response =
        Category
          .take(3)
          .map do |category|
            {
              id: category.id,
              name: category.name,
              slug: category.slug,
              color: category.color,
              score: rand(0.0...45.0),
              topicCount: rand(1..3),
            }
          end
          .sort_by { |h| h[:score] }
      DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:categories).returns(response)
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      ai_suggestion_dropdown.click_suggest_category_button
      wait_for { ai_suggestion_dropdown.has_dropdown? }
      suggestion = category_2.name
      ai_suggestion_dropdown.select_suggestion_by_name(suggestion)

      expect(page).to have_css(".category-chooser summary[data-name='#{suggestion}']")
    end
  end

  context "when suggesting the tags with AI tag suggester" do
    before do
      SiteSetting.ai_embeddings_selected_model = embedding_definition.id
      SiteSetting.ai_embeddings_enabled = true
    end

    it "updates the tag with the suggested tag" do
      response =
        Tag
          .take(7)
          .pluck(:name)
          .map { |s| { name: s, score: rand(0.0...45.0) } }
          .sort { |h| h[:score] }
      DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:tags).returns(response)

      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)

      ai_suggestion_dropdown.click_suggest_tags_button

      wait_for { ai_suggestion_dropdown.has_dropdown? }

      suggestion = ai_suggestion_dropdown.suggestion_name(0)
      ai_suggestion_dropdown.select_suggestion_by_value(0)

      expect(page).to have_css(".mini-tag-chooser summary[data-name='#{suggestion}']")
    end

    it "does not suggest tags that already exist" do
      response =
        Tag
          .take(7)
          .pluck(:name)
          .map { |s| { name: s, score: rand(0.0...45.0) } }
          .sort { |h| h[:score] }
      DiscourseAi::AiHelper::SemanticCategorizer.any_instance.stubs(:tags).returns(response)

      topic_page.visit_topic(topic)
      page.find(".edit-topic", visible: false).click
      page.find(".ai-tag-suggester-trigger").click
      tag1_css = ".ai-tag-suggester-content btn[data-name='#{video.name}']"
      tag2_css = ".ai-tag-suggester-content btn[data-name='#{music.name}']"

      expect(page).to have_no_css(tag1_css)
      expect(page).to have_no_css(tag2_css)
    end
  end

  context "when AI helper is disabled" do
    let(:mode) { DiscourseAi::AiHelper::Assistant::GENERATE_TITLES }
    before { SiteSetting.ai_helper_enabled = false }

    it "does not show the AI helper button in the composer toolbar" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(page).to have_no_css(".d-editor-button-bar button.ai-helper-trigger")
    end

    it "does not trigger AI suggestion buttons" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(ai_suggestion_dropdown).to have_no_suggestion_button
    end
  end

  context "when user is not a member of AI helper allowed group" do
    let(:mode) { DiscourseAi::AiHelper::Assistant::GENERATE_TITLES }
    before { SiteSetting.composer_ai_helper_allowed_groups = non_member_group.id.to_s }

    it "does not show the AI helper button in the composer toolbar" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(page).to have_no_css(".d-editor-button-bar button.ai-helper-trigger")
    end

    it "does not trigger AI suggestion buttons" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(ai_suggestion_dropdown).to have_no_suggestion_button
    end
  end

  context "when suggestion features are disabled" do
    let(:mode) { DiscourseAi::AiHelper::Assistant::GENERATE_TITLES }
    before { SiteSetting.ai_helper_enabled_features = "context_menu" }

    it "does not show suggestion buttons in the composer" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(ai_suggestion_dropdown).to have_no_suggestion_button
    end
  end

  context "when composer helper feature is disabled" do
    before { SiteSetting.ai_helper_enabled_features = "suggestions" }

    it "does not show button in the composer toolbar" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      expect(page).to have_no_css(".d-editor-button-bar button.ai-helper-trigger")
    end
  end

  context "when triggering composer AI helper", mobile: true do
    it "should close the composer helper before showing the diff modal" do
      visit("/latest")
      page.find("#create-topic").click
      composer.fill_content(input)
      composer.click_toolbar_button("ai-helper-trigger")

      DiscourseAi::Completions::Llm.with_prepared_responses([input]) do
        ai_helper_menu.select_helper_model(DiscourseAi::AiHelper::Assistant::TRANSLATE)
        expect(ai_helper_menu).to have_no_context_menu
        expect(diff_modal).to be_visible
      end
    end
  end
end

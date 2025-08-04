# frozen_string_literal: true

include SystemHelpers

RSpec.describe "AI Composer Proofreading Features", type: :system do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_helper_enabled = true

    # This needs to be done because the streaming suggestions for composer
    # happen in a background job, which sends the MessageBus event to the client.
    Jobs.run_immediately!
    sign_in(admin)
  end

  let(:composer) { PageObjects::Components::Composer.new }
  let(:rich) { composer.rich_editor }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:diff_modal) { PageObjects::Modals::DiffModal.new }
  let(:keyboard_shortcut) { [PLATFORM_KEY_MODIFIER, :alt, "p"] }

  context "when triggering via keyboard shortcut" do
    it "proofreads selected text" do
      visit "/new-topic"
      composer.fill_content("hello worldd !")

      composer.select_range(6, 12)

      DiscourseAi::Completions::Llm.with_prepared_responses(["world"]) do
        composer.composer_input.send_keys(keyboard_shortcut)
        expect(diff_modal).to have_diff("worldd", "world")
        diff_modal.confirm_changes
        expect(composer).to have_value("hello world !")
      end
    end

    it "proofreads all text when nothing is selected" do
      visit "/new-topic"
      composer.fill_content("hello worrld")

      # Simulate AI response
      DiscourseAi::Completions::Llm.with_prepared_responses(["hello world"]) do
        composer.composer_input.send_keys(keyboard_shortcut)
        expect(diff_modal).to have_diff("worrld", "world")
        diff_modal.confirm_changes
        expect(composer).to have_value("hello world")
      end
    end

    it "does not trigger proofread modal if composer is empty" do
      visit "/new-topic"

      # Simulate AI response
      DiscourseAi::Completions::Llm.with_prepared_responses(["hello world"]) do
        composer.composer_input.send_keys(keyboard_shortcut)
        expect(toasts).to have_error(I18n.t("js.discourse_ai.ai_helper.no_content_error"))
      end
    end

    context "when using rich text editor" do
      before { SiteSetting.rich_editor = true }

      it "proofreads selected text and replaces it" do
        visit "/new-topic"
        expect(composer).to be_opened
        composer.toggle_rich_editor
        composer.type_content("hello worldd !")

        # NOTE: The rich text editor cannot use select_range on the page object since it is
        # a contenteditable element. It would be hard to make this generic enough to put in
        # the page object, maybe at some point in the future we can refactor this.
        execute_script(<<~JS, text)
          const composer = document.querySelector("#reply-control .d-editor-input");
          const startNode = composer.firstChild.firstChild;
          composer.focus();
          const range = document.createRange();
          range.setStart(startNode, 6);
          range.setEnd(startNode, 12);
          const selection = window.getSelection();
          selection.removeAllRanges();
          selection.addRange(range);
        JS

        DiscourseAi::Completions::Llm.with_prepared_responses(["world"]) do
          composer.composer_input.send_keys(keyboard_shortcut)
          expect(diff_modal).to have_diff("worldd", "world")
          diff_modal.confirm_changes
          expect(rich).to have_css("p", text: "hello world !")
        end
      end
    end
  end
end

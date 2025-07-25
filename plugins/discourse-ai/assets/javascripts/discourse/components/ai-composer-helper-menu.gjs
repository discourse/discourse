import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import DToast from "float-kit/components/d-toast";
import DToastInstance from "float-kit/lib/d-toast-instance";
import AiHelperOptionsList from "../components/ai-helper-options-list";
import ModalDiffModal from "../components/modal/diff-modal";
import ThumbnailSuggestion from "../components/modal/thumbnail-suggestions";

export default class AiComposerHelperMenu extends Component {
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service site;

  @tracked newSelectedText;
  @tracked diff;
  @tracked customPromptValue = "";
  @tracked noContentError = false;
  prompts = [];
  promptTypes = {};

  constructor() {
    super(...arguments);

    if (this.args.data.toolbarEvent.getText().length === 0) {
      this.noContentError = true;
    }
  }

  get helperOptions() {
    let prompts = this.currentUser?.ai_helper_prompts;

    prompts = prompts
      .filter((p) => p.location.includes("composer"))
      .filter((p) => p.name !== "generate_titles")
      .map((p) => {
        // AI helper by default returns interface locale on translations
        // Since we want site default translations (and we are using: force_default_locale)
        // we need to replace the translated_name with the site default locale name
        const siteLocale = this.siteSettings.default_locale;
        const availableLocales = JSON.parse(
          this.siteSettings.available_locales
        );
        const locale = availableLocales.find((l) => l.value === siteLocale);
        const translatedName = i18n(
          "discourse_ai.ai_helper.context_menu.translate_prompt",
          {
            language: locale.name,
          }
        );

        if (p.name === "translate") {
          return { ...p, translated_name: translatedName };
        }
        return p;
      });

    // Find the custom_prompt object and move it to the beginning of the array
    const customPromptIndex = prompts.findIndex(
      (p) => p.name === "custom_prompt"
    );
    if (customPromptIndex !== -1) {
      const customPrompt = prompts.splice(customPromptIndex, 1)[0];
      prompts.unshift(customPrompt);
    }

    if (!this.currentUser?.can_use_custom_prompts) {
      prompts = prompts.filter((p) => p.name !== "custom_prompt");
    }

    prompts.forEach((p) => {
      this.prompts[p.name] = p;
    });

    this.promptTypes = prompts.reduce((memo, p) => {
      memo[p.name] = p.prompt_type;
      return memo;
    }, {});
    return prompts;
  }

  get toast() {
    const owner = getOwner(this);
    const options = {
      close: () => this.args.close(),
      duration: "short",
      data: {
        theme: "error",
        icon: "triangle-exclamation",
        message: i18n("discourse_ai.ai_helper.no_content_error"),
      },
    };

    const custom = class CustomToastInstance extends DToastInstance {
      constructor() {
        super(owner, options);
      }

      @action
      close() {
        this.options.close();
      }
    };

    return new custom(owner, options);
  }

  @action
  async suggestChanges(option) {
    await this.args.close();

    if (option.name === "illustrate_post") {
      return this.modal.show(ThumbnailSuggestion, {
        model: {
          mode: option.name,
          selectedText: this.args.data.selectedText,
          thumbnails: this.thumbnailSuggestions,
        },
      });
    }

    const showResultAsDiff =
      option.prompt_type === "diff" && option.name !== "markdown_table";

    return this.modal.show(ModalDiffModal, {
      model: {
        mode: option.name,
        selectedText: this.args.data.selectedText,
        revert: this.undoAiAction,
        toolbarEvent: this.args.data.toolbarEvent,
        customPromptValue: this.customPromptValue,
        showResultAsDiff,
      },
    });
  }

  @action
  closeMenu() {
    this.customPromptValue = "";
    this.args.close();
  }

  <template>
    {{#if this.noContentError}}
      <DToast @toast={{this.toast}} />
    {{else}}
      <div class="ai-composer-helper-menu">
        {{#if this.site.mobileView}}
          <div class="ai-composer-helper-menu__selected-text">
            {{@data.selectedText}}
          </div>
        {{/if}}

        <AiHelperOptionsList
          @options={{this.helperOptions}}
          @customPromptValue={{this.customPromptValue}}
          @performAction={{this.suggestChanges}}
          @shortcutVisible={{true}}
        />
      </div>
    {{/if}}
  </template>
}

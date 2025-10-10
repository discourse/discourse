import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { and, eq } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import FastEdit from "discourse/components/fast-edit";
import FastEditModal from "discourse/components/modal/fast-edit";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { sanitize } from "discourse/lib/text";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import AiHelperLoading from "../components/ai-helper-loading";
import AiHelperOptionsList from "../components/ai-helper-options-list";
import {
  isAiCreditLimitError,
  popupAiCreditLimitError,
} from "../lib/ai-errors";
import SmoothStreamer from "../lib/smooth-streamer";

export default class AiPostHelperMenu extends Component {
  @service messageBus;
  @service site;
  @service modal;
  @service siteSettings;
  @service currentUser;
  @service menu;
  @service tooltip;

  @tracked menuState = this.MENU_STATES.options;
  @tracked loading = false;
  @tracked suggestion = "";
  @tracked customPromptValue = "";
  @tracked copyButtonIcon = "copy";
  @tracked copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";
  @tracked showFastEdit = false;
  @tracked showAiButtons = true;
  @tracked streaming = false;
  @tracked lastSelectedOption = null;
  @tracked isSavingFootnote = false;
  @tracked supportsAddFootnote = this.args.data.supportsFastEdit;

  @tracked
  smoothStreamer = new SmoothStreamer(
    () => this.suggestion,
    (newValue) => (this.suggestion = newValue)
  );

  MENU_STATES = {
    options: "OPTIONS",
    loading: "LOADING",
    result: "RESULT",
  };

  showFootnoteTooltip = modifier((element) => {
    if (this.supportsAddFootnote || this.streaming) {
      return;
    }

    const instance = this.tooltip.register(element, {
      identifier: "cannot-add-footnote-tooltip",
      content: i18n(
        "discourse_ai.ai_helper.post_options_menu.footnote_disabled"
      ),
      placement: "top",
      triggers: "hover",
    });

    return () => {
      instance.destroy();
    };
  });

  @tracked _activeAiRequest = null;

  get footnoteDisabled() {
    return this.streaming || !this.supportsAddFootnote;
  }

  get helperOptions() {
    let prompts = this.currentUser?.ai_helper_prompts;

    prompts = prompts.filter((item) => item.location.includes("post"));

    // Find the custom_prompt object and move it to the beginning of the array
    const customPromptIndex = prompts.findIndex(
      (p) => p.name === "custom_prompt"
    );

    if (customPromptIndex !== -1) {
      const customPrompt = prompts.splice(customPromptIndex, 1)[0];
      prompts.unshift(customPrompt);
    }

    if (!this._showUserCustomPrompts()) {
      prompts = prompts.filter((p) => p.name !== "custom_prompt");
    }

    if (!this.args.data.canEditPost) {
      prompts = prompts.filter((p) => p.name !== "proofread");
    }

    return prompts;
  }

  get highlightedTextToggleIcon() {
    if (this.showHighlightedText) {
      return "angle-double-left";
    } else {
      return "angle-double-right";
    }
  }

  get allowInsertFootnote() {
    const siteSettings = this.siteSettings;
    const canEditPost = this.args.data.canEditPost;

    if (
      !siteSettings?.enable_markdown_footnotes ||
      !siteSettings?.display_footnotes_inline ||
      !canEditPost
    ) {
      return false;
    }

    return this.lastSelectedOption?.name === "explain";
  }

  _showUserCustomPrompts() {
    return this.currentUser?.can_use_custom_prompts;
  }

  _sanitizeForFootnote(text) {
    // Remove line breaks (line-breaks breaks the inline footnote display)
    text = text.replace(/[\r\n]+/g, " ");

    // Remove headings (headings don't work in inline footnotes)
    text = text.replace(/^(#+)\s+/gm, "");

    // Trim excess space
    text = text.trim();

    return sanitize(text);
  }

  set progressChannel(value) {
    if (this._progressChannel) {
      this.unsubscribe();
    }
    this._progressChannel = value;
    this.subscribe();
  }

  subscribe() {
    this.messageBus.subscribe(this._progressChannel, this._updateResult, 0);
  }

  @bind
  unsubscribe() {
    if (!this._progressChannel) {
      return;
    }
    this.messageBus.unsubscribe(this._progressChannel, this._updateResult);
    this._progressChannel = null;
  }

  @bind
  async _updateResult(result) {
    if (isAiCreditLimitError(result)) {
      this.loading = false;
      this.menuState = this.MENU_STATES.triggers;
      popupAiCreditLimitError(result);
      return;
    }

    this.streaming = !result.done;
    await this.smoothStreamer.updateResult(result, "result");
  }

  @action
  toggleHighlightedTextPreview() {
    this.showHighlightedText = !this.showHighlightedText;
  }

  @action
  async performAiSuggestion(option) {
    this.menuState = this.MENU_STATES.loading;
    this.lastSelectedOption = option;
    const streamableOptions = ["explain", "translate", "custom_prompt"];

    try {
      if (streamableOptions.includes(option.name)) {
        const streamedResult = await this._handleStreamedResult(option);
        this.progressChannel = streamedResult.progress_channel;
        return;
      } else {
        this._activeAiRequest = ajax("/discourse-ai/ai-helper/suggest", {
          method: "POST",
          data: {
            mode: option.name,
            text: this.args.data.quoteState.buffer,
            custom_prompt: this.customPromptValue,
          },
        });
      }

      this._activeAiRequest
        .then(({ suggestions }) => {
          this.suggestion = suggestions[0].trim();

          if (option.name === "proofread") {
            return this._handleProofreadOption();
          }
        })
        .finally(() => {
          this.loading = false;
          this.menuState = this.MENU_STATES.result;
        });
    } catch (error) {
      if (isAiCreditLimitError(error)) {
        popupAiCreditLimitError(error);
      } else {
        popupAjaxError(error);
      }
      this.loading = false;
      this.menuState = this.MENU_STATES.triggers;
    }

    return this._activeAiRequest;
  }

  _handleStreamedResult(option) {
    this.menuState = this.MENU_STATES.result;
    const menu = this.menu.getByIdentifier("post-text-selection-toolbar");
    if (menu) {
      menu.options.placement = "bottom";
    }
    const fetchUrl = `/discourse-ai/ai-helper/stream_suggestion`;

    this._activeAiRequest = ajax(fetchUrl, {
      method: "POST",
      data: {
        location: "post",
        mode: option.name,
        text: this.args.data.quoteState.buffer,
        post_id: this.args.data.quoteState.postId,
        custom_prompt: this.customPromptValue,
        client_id: this.messageBus.clientId,
      },
    });

    return this._activeAiRequest;
  }

  _handleProofreadOption() {
    this.showAiButtons = false;

    if (this.site.desktopView) {
      this.showFastEdit = true;
      return;
    } else {
      return this.modal.show(FastEditModal, {
        model: {
          initialValue: this.args.data.quoteState.buffer,
          newValue: this.suggestion,
          post: this.args.data.post,
          close: this.closeFastEdit,
        },
      });
    }
  }

  @action
  cancelAiAction() {
    if (this._activeAiRequest) {
      this._activeAiRequest.abort();
      this._activeAiRequest = null;
      this.loading = false;
      this.menuState = this.MENU_STATES.options;
    }
  }

  @action
  copySuggestion() {
    if (this.suggestion?.length > 0) {
      clipboardCopy(this.suggestion);
      this.copyButtonIcon = "check";
      this.copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copied";
      setTimeout(() => {
        this.copyButtonIcon = "copy";
        this.copyButtonLabel = "discourse_ai.ai_helper.post_options_menu.copy";
      }, 3500);
    }
  }

  @action
  closeMenu() {
    // reset state and close
    this.suggestion = "";
    this.customPromptValue = "";
    return this.args.close();
  }

  @action
  async closeFastEdit() {
    this.showFastEdit = false;
    await this.args.data.hideToolbar();
  }

  @action
  async insertFootnote() {
    this.isSavingFootnote = true;

    if (this.allowInsertFootnote) {
      try {
        const result = await ajax(`/posts/${this.args.data.post.id}`);
        const sanitizedSuggestion = this._sanitizeForFootnote(this.suggestion);
        const credits = i18n(
          "discourse_ai.ai_helper.post_options_menu.footnote_credits"
        );
        const withFootnote = `${this.args.data.quoteState.buffer} ^[${sanitizedSuggestion} (${credits})]`;
        const newRaw = result.raw.replace(
          this.args.data.quoteState.buffer,
          withFootnote
        );

        await this.args.data.post.save({ raw: newRaw });
      } catch (error) {
        if (isAiCreditLimitError(error)) {
          popupAiCreditLimitError(error);
        } else {
          popupAjaxError(error);
        }
      } finally {
        this.isSavingFootnote = false;
        await this.closeMenu();
      }
    }
  }

  <template>
    {{#if
      (and this.site.mobileView (eq this.menuState this.MENU_STATES.options))
    }}
      <div class="ai-post-helper-menu__selected-text">
        {{@data.quoteState.buffer}}
      </div>
    {{/if}}

    {{#if this.showAiButtons}}
      <div class="ai-post-helper">
        {{#if (eq this.menuState this.MENU_STATES.options)}}
          <AiHelperOptionsList
            @options={{this.helperOptions}}
            @customPromptValue={{this.customPromptValue}}
            @performAction={{this.performAiSuggestion}}
            @shortcutVisible={{false}}
          />
        {{else if (eq this.menuState this.MENU_STATES.loading)}}
          <AiHelperLoading @cancel={{this.cancelAiAction}} />
        {{else if (eq this.menuState this.MENU_STATES.result)}}
          <div
            class="ai-post-helper__suggestion"
            {{willDestroy this.unsubscribe}}
          >
            {{#if this.suggestion}}
              <div
                class={{concatClass
                  (if this.smoothStreamer.isStreaming "streaming")
                  "streamable-content"
                  "ai-post-helper__suggestion__text"
                }}
                dir="auto"
              >
                <CookText
                  @rawText={{this.smoothStreamer.renderedText}}
                  class="cooked"
                />
              </div>
              <div class="ai-post-helper__suggestion__buttons">
                <DButton
                  @icon="xmark"
                  @label="discourse_ai.ai_helper.post_options_menu.cancel"
                  @action={{this.cancelAiAction}}
                  class="btn-flat ai-post-helper__suggestion__cancel"
                />
                <DButton
                  @icon={{this.copyButtonIcon}}
                  @label={{this.copyButtonLabel}}
                  @action={{this.copySuggestion}}
                  @disabled={{this.streaming}}
                  class="btn-flat ai-post-helper__suggestion__copy"
                />
                {{#if this.allowInsertFootnote}}
                  <DButton
                    @icon="asterisk"
                    @label="discourse_ai.ai_helper.post_options_menu.insert_footnote"
                    @action={{this.insertFootnote}}
                    @isLoading={{this.isSavingFootnote}}
                    @disabled={{this.footnoteDisabled}}
                    class="btn-flat ai-post-helper__suggestion__insert-footnote"
                    {{this.showFootnoteTooltip}}
                  />
                {{/if}}
              </div>
            {{else}}
              <AiHelperLoading @cancel={{this.cancelAiAction}} />
            {{/if}}
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if this.showFastEdit}}
      <div class="ai-post-helper__fast-edit">
        <FastEdit
          @initialValue={{@data.quoteState.buffer}}
          @newValue={{this.suggestion}}
          @post={{@data.post}}
          @close={{this.closeFastEdit}}
        />
      </div>
    {{/if}}
  </template>
}

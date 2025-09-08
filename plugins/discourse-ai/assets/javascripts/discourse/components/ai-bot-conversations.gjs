/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import $ from "jquery";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import userAutocomplete from "discourse/lib/autocomplete/user";
import {
  hashtagAutocompleteOptions,
  setupHashtagAutocomplete,
} from "discourse/lib/hashtag-autocomplete";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import userSearch, { validateSearchResult } from "discourse/lib/user-search";
import {
  destroyUserStatuses,
  initUserStatusHtml,
  renderUserStatusHtml,
} from "discourse/lib/user-status-on-autocomplete";
import { clipboardHelpers } from "discourse/lib/utilities";
import DAutocompleteModifier from "discourse/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import AiPersonaLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-persona-llm-selector";

export default class AiBotConversations extends Component {
  @service aiBotConversationsHiddenSubmit;
  @service capabilities;
  @service mediaOptimizationWorker;
  @service site;
  @service siteSettings;

  @tracked uploads = new TrackedArray();
  // Don't track this directly - we'll get it from uppyUpload

  textarea = null;
  uppyUpload = null;
  fileInputEl = null;

  _handlePaste = (event) => {
    if (document.activeElement !== this.textarea) {
      return;
    }

    const { canUpload, canPasteHtml, types } = clipboardHelpers(event, {
      siteSettings: this.siteSettings,
      canUpload: true,
    });

    if (!canUpload || canPasteHtml || types.includes("text/plain")) {
      return;
    }

    if (event && event.clipboardData && event.clipboardData.files) {
      this.uppyUpload.addFiles([...event.clipboardData.files], {
        pasted: true,
      });
    }
  };

  init() {
    super.init(...arguments);

    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: "ai-bot-file-uploader",
      type: "ai-bot-conversation",
      useMultipartUploadsIfAvailable: true,

      uppyReady: () => {
        if (this.siteSettings.composer_media_optimization_image_enabled) {
          this.uppyUpload.uppyWrapper.useUploadPlugin(UppyMediaOptimization, {
            optimizeFn: (data, opts) =>
              this.mediaOptimizationWorker.optimizeImage(data, opts),
            runParallel: !this.capabilities.isMobileDevice,
          });
        }

        this.uppyUpload.uppyWrapper.onPreProcessProgress((file) => {
          const inProgressUpload = this.inProgressUploads?.find(
            (upl) => upl.id === file.id
          );
          if (inProgressUpload && !inProgressUpload.processing) {
            inProgressUpload.processing = true;
          }
        });

        this.uppyUpload.uppyWrapper.onPreProcessComplete((file) => {
          const inProgressUpload = this.inProgressUploads?.find(
            (upl) => upl.id === file.id
          );
          if (inProgressUpload) {
            inProgressUpload.processing = false;
          }
        });

        this.textarea?.addEventListener("paste", this._handlePaste);
      },

      uploadDone: (upload) => {
        this.uploads.push(upload);
      },

      // Fix: Don't try to set inProgressUploads directly
      onProgressUploadsChanged: () => {
        // This is just for UI triggers - we're already tracking inProgressUploads
        this.notifyPropertyChange("inProgressUploads");
      },
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.textarea?.removeEventListener("paste", this._handlePaste);
    this.uppyUpload?.teardown();
    // needed for safety (textarea may not have a autocomplete)
    if (this.textarea.autocomplete) {
      this.textarea.autocomplete("destroy");
    }
  }

  get loading() {
    return this.aiBotConversationsHiddenSubmit?.loading;
  }

  get inProgressUploads() {
    return this.uppyUpload?.inProgressUploads || [];
  }

  get showUploadsContainer() {
    return this.uploads?.length > 0 || this.inProgressUploads?.length > 0;
  }

  @action
  setPersonaId(id) {
    this.aiBotConversationsHiddenSubmit.personaId = id;
  }

  @action
  setTargetRecipient(username) {
    this.aiBotConversationsHiddenSubmit.targetUsername = username;
  }

  @action
  updateInputValue(value) {
    this._autoExpandTextarea();
    this.aiBotConversationsHiddenSubmit.inputValue =
      value.target?.value || value;
  }

  @action
  handleKeyDown(event) {
    if (event.target.tagName !== "TEXTAREA") {
      return;
    }
    if (event.key === "Enter" && !event.shiftKey) {
      this.prepareAndSubmitToBot();
    }
  }

  @action
  setTextArea(element) {
    this.textarea = element;
    this.setupAutocomplete(element);
    scheduleOnce("afterRender", this, this.focusTextarea);
  }

  @action
  focusTextarea() {
    this.textarea?.focus();
  }

  @action
  setupAutocomplete(textarea) {
    this.applyUserAutocomplete(textarea);
    this.applyHashtagAutocomplete(textarea);
  }

  @action
  applyUserAutocomplete(textarea) {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    if (!this.siteSettings.floatkit_autocomplete_chat_composer) {
      $(textarea).autocomplete({
        template: userAutocomplete,
        dataSource: (term) => {
          destroyUserStatuses();
          return userSearch({
            term,
            includeGroups: true,
          }).then((result) => {
            initUserStatusHtml(getOwner(this), result.users);
            return result;
          });
        },
        onRender: (options) => renderUserStatusHtml(options),
        key: "@",
        width: "100%",
        treatAsTextarea: true,
        autoSelectFirstSuggestion: true,
        transformComplete: (obj) => {
          validateSearchResult(obj);
          return obj.username || obj.name;
        },
        afterComplete: (text) => {
          this.textarea.value = text;
          this.focusTextarea();
          this.updateInputValue({ target: { value: text } });
        },
        onClose: destroyUserStatuses,
      });
    }

    const autocompleteHandler = new TextareaAutocompleteHandler(textarea);
    DAutocompleteModifier.setupAutocomplete(
      getOwner(this),
      textarea,
      autocompleteHandler,
      {
        template: userAutocomplete,
        dataSource: (term) => {
          destroyUserStatuses();
          return userSearch({
            term,
            includeGroups: true,
          }).then((result) => {
            initUserStatusHtml(getOwner(this), result.users);
            return result;
          });
        },
        onRender: (options) => renderUserStatusHtml(options),
        key: "@",
        fixedTextareaPosition: true,
        autoSelectFirstSuggestion: true,
        offset: 2,
        transformComplete: (obj) => {
          validateSearchResult(obj);
          return obj.username || obj.name;
        },
        afterComplete: (text) => {
          this.textarea.value = text;
          this.focusTextarea();
          this.updateInputValue({ target: { value: text } });
        },
        onClose: destroyUserStatuses,
      }
    );
  }

  @action
  applyHashtagAutocomplete(textarea) {
    // Use the "topic-composer" configuration or create a specific one for AI bot
    // You can change this to "chat-composer" if that's more appropriate
    const hashtagConfig = this.site.hashtag_configurations["topic-composer"];

    if (!this.siteSettings.floatkit_autocomplete_chat_composer) {
      setupHashtagAutocomplete(hashtagConfig, $(textarea), {
        treatAsTextarea: true,
        afterComplete: (text) => {
          this.textarea.value = text;
          this.focusTextarea();
          this.updateInputValue({ target: { value: text } });
        },
      });
    }
    const autocompleteHandler = new TextareaAutocompleteHandler(textarea);
    DAutocompleteModifier.setupAutocomplete(
      getOwner(this),
      textarea,
      autocompleteHandler,
      hashtagAutocompleteOptions(hashtagConfig, {
        offset: 2,
        fixedTextareaPosition: true,
        afterComplete: (text) => {
          this.textarea.value = text;
          this.focusTextarea();
          this.updateInputValue({ target: { value: text } });
        },
      })
    );
  }

  @action
  registerFileInput(element) {
    if (element) {
      this.fileInputEl = element;
      if (this.uppyUpload) {
        this.uppyUpload.setup(element);
      }
    }
  }

  @action
  openFileUpload() {
    if (this.fileInputEl) {
      this.fileInputEl.click();
    }
  }

  @action
  removeUpload(upload) {
    this.uploads = new TrackedArray(this.uploads.filter((u) => u !== upload));
  }

  @action
  cancelUpload(upload) {
    this.uppyUpload.cancelSingleUpload({
      fileId: upload.id,
    });
  }

  @action
  async prepareAndSubmitToBot() {
    try {
      await this.aiBotConversationsHiddenSubmit.submitToBot({
        uploads: this.uploads,
        inProgressUploadsCount: this.inProgressUploads.length,
      });
      this.uploads = new TrackedArray();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  _autoExpandTextarea() {
    this.textarea.style.height = "auto";
    this.textarea.style.height = this.textarea.scrollHeight + "px";

    // Get the max-height value from CSS (30vh)
    const maxHeight = parseInt(getComputedStyle(this.textarea).maxHeight, 10);

    // Only enable scrolling if content exceeds max-height
    if (this.textarea.scrollHeight > maxHeight) {
      this.textarea.style.overflowY = "auto";
    } else {
      this.textarea.style.overflowY = "hidden";
    }
  }

  <template>
    <div class="ai-bot-conversations">
      {{bodyClass "ai-bot-conversations-page"}}
      <AiPersonaLlmSelector
        @showLabels={{true}}
        @setPersonaId={{this.setPersonaId}}
        @setTargetRecipient={{this.setTargetRecipient}}
        @personaName={{@controller.persona}}
        @llmName={{@controller.llm}}
      />

      <div class="ai-bot-conversations__content-wrapper">
        <div class="ai-bot-conversations__title">
          {{i18n "discourse_ai.ai_bot.conversations.header"}}
        </div>
        <PluginOutlet
          @name="ai-bot-conversations-above-input"
          @outletArgs={{lazyHash
            updateInput=this.updateInputValue
            submit=this.prepareAndSubmitToBot
          }}
        />

        <div class="ai-bot-conversations__input-wrapper">
          <DButton
            @icon="upload"
            @action={{this.openFileUpload}}
            @title="discourse_ai.ai_bot.conversations.upload_files"
            class="btn btn-transparent ai-bot-upload-btn"
          />
          <textarea
            {{didInsert this.setTextArea}}
            {{on "input" this.updateInputValue}}
            {{on "keydown" this.handleKeyDown}}
            id="ai-bot-conversations-input"
            autofocus="true"
            placeholder={{i18n "discourse_ai.ai_bot.conversations.placeholder"}}
            minlength="10"
            disabled={{this.loading}}
            rows="1"
          />
          <DButton
            @action={{this.prepareAndSubmitToBot}}
            @icon="paper-plane"
            @isLoading={{this.loading}}
            @title="discourse_ai.ai_bot.conversations.header"
            class="ai-bot-button btn-transparent ai-conversation-submit"
          />
          <input
            type="file"
            id="ai-bot-file-uploader"
            class="hidden-upload-field"
            multiple="multiple"
            {{didInsert this.registerFileInput}}
          />
        </div>

        <p class="ai-disclaimer">
          {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
        </p>

        {{#if this.showUploadsContainer}}
          <div class="ai-bot-conversations__uploads-container">
            {{#each this.uploads as |upload|}}
              <div class="ai-bot-upload">
                <span class="ai-bot-upload__filename">
                  {{upload.original_filename}}
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn this.removeUpload upload}}
                  class="btn-transparent ai-bot-upload__remove"
                />
              </div>
            {{/each}}

            {{#each this.inProgressUploads as |upload|}}
              <div class="ai-bot-upload ai-bot-upload--in-progress">
                <span class="ai-bot-upload__filename">{{upload.fileName}}</span>
                <span class="ai-bot-upload__progress">
                  {{upload.progress}}%
                </span>
                <DButton
                  @icon="xmark"
                  @action={{fn this.cancelUpload upload}}
                  class="btn-flat ai-bot-upload__cancel"
                />
              </div>
            {{/each}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}

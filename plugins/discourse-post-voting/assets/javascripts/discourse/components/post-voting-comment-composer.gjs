import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import {
  authorizesOneOrMoreExtensions,
  getUploadMarkdown,
} from "discourse/lib/uploads";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { i18n } from "discourse-i18n";

const ALLOWED_TOOLBAR_BUTTONS = [
  "bold",
  "italic",
  "link",
  "blockquote",
  "code",
  "bullet",
  "list",
];

export default class PostVotingCommentComposer extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked value = this.args.raw ?? "";
  @tracked uploading = false;

  textManipulation = null;
  uppyUpload = null;
  fileInputId = `post-voting-comment-file-input-${Date.now()}`;
  composerElement = null;

  constructor() {
    super(...arguments);
    this.#initUpload();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.uppyUpload?.teardown();
  }

  #initUpload() {
    if (!this.currentUser) {
      return;
    }

    this.uppyUpload = new UppyUpload(getOwner(this), {
      id: `post-voting-comment-uppy-${Date.now()}`,
      type: "composer",
      uploadDropTargetOptions: () => this.#dropTargetOptions(),
      uploadDone: (upload) => {
        const markdown = getUploadMarkdown(upload);
        if (this.textManipulation) {
          this.textManipulation.addText(
            this.textManipulation.getSelected(),
            markdown
          );
        } else {
          // Fallback: append to value
          this.value = this.value + (this.value ? "\n" : "") + markdown;
          this.args.onInput?.(this.value);
        }
      },
      uploadError: () => {
        this.uploading = false;
      },
    });
  }

  #dropTargetOptions() {
    return this.composerElement ? { target: this.composerElement } : null;
  }

  @action
  onInput(event) {
    this.value = event.target.value;
    this.args.onInput?.(event.target.value);
  }

  @action
  setupEditor(textManipulation) {
    this.textManipulation = textManipulation;

    return () => {
      this.textManipulation = null;
    };
  }

  @action
  registerComposerElement(element) {
    this.composerElement = element;
    // Set up Uppy with the composer element as the drop target
    // We pass null for the file input since we'll bind it separately
    if (this.uppyUpload && !this.uppyUpload.uppyWrapper?.uppyInstance) {
      this.uppyUpload.setup(null);
    }
  }

  @action
  registerFileInput(element) {
    // Bind the file input change listener manually since we called setup() without it
    if (element && this.uppyUpload) {
      element.addEventListener("change", (event) => {
        const files = Array.from(event.target.files);
        if (files.length > 0) {
          this.uppyUpload.addFiles(files);
          element.value = "";
        }
      });
    }
  }

  @action
  configureToolbar(toolbar) {
    // Filter to allowed buttons
    toolbar.groups.forEach((group) => {
      group.buttons = group.buttons.filter((button) =>
        ALLOWED_TOOLBAR_BUTTONS.includes(button.id)
      );
    });

    toolbar.groups = toolbar.groups.filter((group) => group.buttons.length > 0);

    // Add upload button if uploads are allowed
    if (this.canUpload) {
      toolbar.addButton({
        id: "upload",
        group: "insertions",
        icon: "upload",
        title: "upload",
        sendAction: () => this.triggerUpload(),
      });
    }
  }

  get canUpload() {
    return (
      this.currentUser &&
      authorizesOneOrMoreExtensions(
        this.currentUser.staff,
        this.siteSettings
      ) &&
      this.uppyUpload
    );
  }

  @action
  triggerUpload() {
    const fileInput = document.getElementById(this.fileInputId);
    fileInput?.click();
  }

  get errorMessage() {
    if (this.value.length < this.siteSettings.min_post_length) {
      return i18n("post_voting.post.post_voting_comment.composer.too_short", {
        count: this.siteSettings.min_post_length,
      });
    }

    if (
      this.value.length > this.siteSettings.post_voting_comment_max_raw_length
    ) {
      return i18n("post_voting.post.post_voting_comment.composer.too_long", {
        count: this.siteSettings.post_voting_comment_max_raw_length,
      });
    }
  }

  get remainingCharacters() {
    return (
      this.siteSettings.post_voting_comment_max_raw_length - this.value.length
    );
  }

  <template>
    {{! template-lint-disable no-invalid-interactive }}
    <div
      class="post-voting-comment-composer"
      {{on "keydown" @onKeyDown}}
      {{didInsert this.registerComposerElement}}
    >
      <DEditor
        class="post-voting-comment-composer-editor"
        @value={{this.value}}
        @change={{this.onInput}}
        @processPreview={{false}}
        @extraButtons={{this.configureToolbar}}
        @onSetup={{this.setupEditor}}
      />

      {{#if this.canUpload}}
        <input
          type="file"
          id={{this.fileInputId}}
          class="hidden-upload-field"
          multiple={{true}}
          {{didInsert this.registerFileInput}}
        />
      {{/if}}

      {{#if this.value.length}}
        {{#if this.errorMessage}}
          <div class="post-voting-comment-composer-flash error">
            {{this.errorMessage}}
          </div>
        {{else}}
          <div class="post-voting-comment-composer-flash">
            {{i18n
              "post_voting.post.post_voting_comment.composer.length_ok"
              count=this.remainingCharacters
            }}
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import IframedHtml from "discourse/components/iframed-html";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";

export default class RawEmailComponent extends Component {
  @tracked rawEmail = this.args.model.rawEmail || "";
  @tracked textPart = "";
  @tracked htmlPart = "";
  @tracked tab = "raw";

  constructor() {
    super(...arguments);
    if (this.args.model.id) {
      this.loadRawEmail(this.args.model.id);
    }
  }

  @action
  async loadRawEmail(postId) {
    const result = await Post.loadRawEmail(postId);
    this.rawEmail = result.raw_email;
    this.textPart = result.text_part;
    this.htmlPart = result.html_part;
  }

  @action
  displayRaw() {
    this.tab = "raw";
  }

  @action
  displayTextPart() {
    this.tab = "text_part";
  }

  @action
  displayHtmlPart() {
    this.tab = "html_part";
  }

  <template>
    <DModal
      @title={{i18n "raw_email.title"}}
      class="incoming-email-modal"
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="incoming-email-tabs">
          <DButton
            @action={{this.displayRaw}}
            @label="post.raw_email.displays.raw.button"
            @title="post.raw_email.displays.raw.title"
            class={{if (eq this.tab "raw") "active"}}
          />

          {{#if this.textPart}}
            <DButton
              @action={{this.displayTextPart}}
              @label="post.raw_email.displays.text_part.button"
              @title="post.raw_email.displays.text_part.title"
              class={{if (eq this.tab "text_part") "active"}}
            />
          {{/if}}

          {{#if this.htmlPart}}
            <DButton
              @action={{this.displayHtmlPart}}
              @label="post.raw_email.displays.html_part.button"
              @title="post.raw_email.displays.html_part.title"
              class={{if (eq this.tab "html_part") "active"}}
            />
          {{/if}}
        </div>

        <div class="incoming-email-content">
          {{#if (eq this.tab "raw")}}
            {{#if this.rawEmail}}
              <Textarea @value={{this.rawEmail}} />
            {{else}}
              {{i18n "raw_email.not_available"}}
            {{/if}}
          {{/if}}
          {{#if (eq this.tab "text_part")}}
            <Textarea @value={{this.textPart}} />
          {{/if}}
          {{#if (eq this.tab "html_part")}}
            <IframedHtml
              @html={{this.htmlPart}}
              class="incoming-email-html-part"
            />
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}

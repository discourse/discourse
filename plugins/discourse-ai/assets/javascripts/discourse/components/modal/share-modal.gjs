import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import discourseLater from "discourse/lib/later";
import { i18n } from "discourse-i18n";
import { showShareConversationModal } from "../../lib/ai-bot-helper";
import copyConversation from "../../lib/copy-conversation";

export default class ShareModal extends Component {
  @service modal;
  @service siteSettings;
  @service currentUser;

  @tracked contextValue = 1;
  @tracked htmlContext = "";
  @tracked maxContext = 0;
  @tracked allPosts = [];
  @tracked justCopiedText = "";

  constructor() {
    super(...arguments);

    const postStream = this.args.model.topic.get("postStream");

    let postNumbers = [];
    // simpler to understand than Array.from
    for (let i = 1; i <= this.args.model.post_number; i++) {
      postNumbers.push(i);
    }

    this.allPosts = postNumbers
      .map((postNumber) => {
        let postId = postStream.findPostIdForPostNumber(postNumber);
        if (postId) {
          return postStream.findLoadedPost(postId);
        }
      })
      .filter((post) => post);

    this.maxContext = this.allPosts.length / 2;
    this.contextValue = 1;

    this.updateHtmlContext();
  }

  @action
  updateHtmlContext() {
    let context = [];

    const start = this.allPosts.length - this.contextValue * 2;
    for (let i = start; i < this.allPosts.length; i++) {
      const post = this.allPosts[i];
      context.push(`<p><b>${post.username}:</b></p>`);
      context.push(post.cooked);
    }
    this.htmlContext = htmlSafe(context.join("\n"));
  }

  @action
  async copyContext() {
    const from =
      this.allPosts[this.allPosts.length - this.contextValue * 2].post_number;
    const to = this.args.model.post_number;

    await copyConversation(this.args.model.topic, from, to);
    this.justCopiedText = i18n("discourse_ai.ai_bot.conversation_shared");

    discourseLater(() => {
      this.justCopiedText = "";
    }, 2000);
  }

  @action
  shareConversationModal(event) {
    event?.preventDefault();
    this.args.closeModal();
    showShareConversationModal(this.modal, this.args.model.topic_id);
    return false;
  }

  <template>
    <DModal
      class="ai-share-modal"
      @title={{i18n "discourse_ai.ai_bot.share_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <div class="ai-share-modal__preview">
          {{this.htmlContext}}
        </div>
      </:body>

      <:footer>
        <div class="ai-share-modal__slider">
          <Input
            @type="range"
            min="1"
            max={{this.maxContext}}
            @value={{this.contextValue}}
            {{on "change" this.updateHtmlContext}}
          />
          <div class="ai-share-modal__context">
            {{i18n "discourse_ai.ai_bot.share_modal.context"}}
            {{this.contextValue}}
          </div>
        </div>
        <DButton
          class="btn-primary confirm"
          @icon="copy"
          @action={{this.copyContext}}
          @label="discourse_ai.ai_bot.share_modal.copy"
        />
        <span class="ai-share-modal__just-copied">{{this.justCopiedText}}</span>
        {{#if this.currentUser.can_share_ai_bot_conversations}}
          <a href {{on "click" this.shareConversationModal}}>
            <span class="ai-share-modal__share-tip">
              {{i18n "discourse_ai.ai_bot.share_modal.share_tip"}}
            </span>
          </a>
        {{/if}}
      </:footer>
    </DModal>
  </template>
}

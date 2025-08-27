import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import {
  invalidateDraftState,
  matchesPost,
  setDraftFromTopic,
  setDraftSaved,
} from "discourse/lib/draft-state-cache";
import { i18n } from "discourse-i18n";

/**
 * @component PostMenuReplyButton
 *
 * Renders the per-post reply action button. When a topic-level reply draft exists,
 * the button shows "Open Draft" and a corresponding tooltip; otherwise it shows "Reply".
 *
 * @param {object} post - The post this button belongs to (this.args.post)
 * @param {object} state - Menu state (this.args.state)
 * @param {object} buttonActions - Reply action handlers
 */
export default class PostMenuReplyButton extends Component {
  static shouldRender(args) {
    return args.state.canCreatePost;
  }

  @service site;
  @service appEvents;

  @tracked hasMatchingDraft = false;

  constructor() {
    super(...arguments);
    setDraftFromTopic(this.args.post?.topic);
    this._checkDraft();
    this.appEvents.on("composer:cancelled", this, this._onDraftChanged);
    this.appEvents.on("draft:destroyed", this, this._onDraftChanged);
    // MessageBus user-drafts updates; store is updated elsewhere
    this.appEvents.on("user-drafts:changed", this, this._checkDraft);
    this.appEvents.on("draft:saved", this, this._onDraftSaved);
  }

  willDestroy() {
    super.willDestroy?.(...arguments);
    this.appEvents.off("composer:cancelled", this, this._onDraftChanged);
    this.appEvents.off("draft:destroyed", this, this._onDraftChanged);
    this.appEvents.off("user-drafts:changed", this, this._checkDraft);
    this.appEvents.off("draft:saved", this, this._onDraftSaved);
  }

  async _checkDraft() {
    const key = this.args.post?.topic?.draft_key;
    if (!key) {
      this.hasMatchingDraft = false;
      return;
    }
    const postId = this.args.post?.id;
    this.hasMatchingDraft = matchesPost(key, postId);
  }

  _onDraftChanged() {
    const key = this.args.post?.topic?.draft_key;
    if (key) {
      invalidateDraftState(key);
    }
    this._checkDraft();
  }

  _onDraftSaved(payload) {
    const key = this.args.post?.topic?.draft_key;
    if (key && payload?.draftKey === key) {
      setDraftSaved(key, { postId: payload.postId, action: payload.action });
      this._checkDraft();
    }
  }

  /**
   * @returns {boolean} whether to show the textual label next to the icon
   */
  get showLabel() {
    return (
      this.args.showLabel ??
      (this.site.desktopView && !this.args.state.isWikiMode)
    );
  }

  /**
   * @returns {string} i18n key for the button label
   */
  get label() {
    return this.hasMatchingDraft ? "topic.open_draft" : "topic.reply.title";
  }

  /**
   * @returns {string} i18n key for the button tooltip
   */
  get title() {
    return this.hasMatchingDraft
      ? "post.controls.open_draft"
      : "post.controls.reply";
  }

  <template>
    <DButton
      class={{concatClass
        "post-action-menu__reply"
        "reply"
        (if this.showLabel "create fade-out")
      }}
      ...attributes
      @action={{@buttonActions.replyToPost}}
      @icon="reply"
      @label={{if this.showLabel this.label}}
      @title={{this.title}}
      @translatedAriaLabel={{i18n
        "post.sr_reply_to"
        post_number=@post.post_number
        username=@post.username
      }}
    />
  </template>
}

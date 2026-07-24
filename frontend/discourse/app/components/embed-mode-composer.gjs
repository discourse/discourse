import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DockedComposer from "discourse/components/docked-composer";
import { ajax } from "discourse/lib/ajax";
import EmbedMode from "discourse/lib/embed-mode";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

export default class EmbedModeComposer extends Component {
  @service appEvents;
  @service currentUser;
  @service embedAuthFlow;
  @service site;
  @service store;

  @tracked replyingToPost = null;
  @tracked editingPost = null;
  @tracked isSubmitting = false;
  @tracked footerVisible = true;

  setupEvents = modifier((element) => {
    this.#rootElement = element;
    this.appEvents.on(
      "embed-composer:reply-to-post",
      this,
      this.handleReplyToPost
    );
    this.appEvents.on("embed-composer:edit-post", this, this.handleEditPost);
    this.appEvents.on("embed-composer:focus", this, this.handleFocus);

    const footerButtons = document.querySelector("#topic-footer-buttons");
    const embedFooter = document.querySelector(".embed-topic-footer");
    const targets = [footerButtons, embedFooter].filter(Boolean);

    if (targets.length > 0) {
      const visibilityMap = new Map();
      targets.forEach((t) => visibilityMap.set(t, false));

      this.#footerObserver = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            visibilityMap.set(entry.target, entry.isIntersecting);
          });
          this.footerVisible = [...visibilityMap.values()].some(Boolean);
        },
        { threshold: 0 }
      );

      targets.forEach((t) => this.#footerObserver.observe(t));
    }

    return () => {
      this.#rootElement = null;
      this.#footerObserver?.disconnect();
      this.appEvents.off(
        "embed-composer:reply-to-post",
        this,
        this.handleReplyToPost
      );
      this.appEvents.off("embed-composer:edit-post", this, this.handleEditPost);
      this.appEvents.off("embed-composer:focus", this, this.handleFocus);
    };
  });

  #composerApi = null;
  #footerObserver = null;
  #rootElement = null;

  get show() {
    if (!EmbedMode.enabled) {
      return false;
    }
    return this.currentUser && this.args.topic?.details?.can_create_post;
  }

  get showSigninCta() {
    if (!EmbedMode.enabled || this.currentUser) {
      return false;
    }
    return this.embedAuthFlow.isActive;
  }

  get showFloatingTimelineButton() {
    return this.args.topic?.replyCount > 0 && !this.footerVisible;
  }

  get draftKey() {
    return `embed-reply-${this.args.topic?.id}`;
  }

  get placeholder() {
    return i18n("embed_mode.reply_placeholder");
  }

  @action
  handleReplyToPost(post) {
    if (this.editingPost) {
      this.editingPost = null;
      this.#composerApi?.setReply("");
    }
    if (post && post.post_number !== 1) {
      this.replyingToPost = post;
    } else {
      this.replyingToPost = null;
    }
    schedule("afterRender", () => {
      this.#rootElement?.querySelector(".d-editor-input")?.focus();
    });
  }

  @action
  handleFocus() {
    this.#rootElement?.querySelector(".d-editor-input")?.focus();
  }

  @action
  handleTimelineToggle() {
    this.appEvents.trigger("topic:toggle-progress-expansion");
  }

  @action
  clearReplyingTo() {
    this.replyingToPost = null;
  }

  @action
  registerComposerApi(api) {
    this.#composerApi = api;
  }

  @action
  async handleEditPost(post) {
    this.replyingToPost = null;
    const fullPost = await this.store.find("post", post.id);
    this.editingPost = fullPost;
    this.#composerApi?.setReply(fullPost.raw);
    schedule("afterRender", () => {
      this.#rootElement?.querySelector(".d-editor-input")?.focus();
    });
  }

  @action
  cancelEditing() {
    this.editingPost = null;
    this.#composerApi?.setReply("");
  }

  @action
  handleSigninCtaClick() {
    this.embedAuthFlow.requestAccess({ intent: "login" });
  }

  @action
  async handleSubmit({ raw }) {
    if (this.editingPost) {
      return this.#submitEdit(raw);
    }
    return this.#submitReply(raw);
  }

  async #submitEdit(raw) {
    const post = this.editingPost;
    this.isSubmitting = true;

    try {
      const result = await ajax(`/posts/${post.id}.json`, {
        type: "PUT",
        data: { post: { raw } },
      });

      const postStream = this.args.topic.postStream;
      const loadedPost = postStream.findLoadedPost(post.id);
      if (loadedPost) {
        loadedPost.setProperties({
          raw: result.post.raw,
          cooked: result.post.cooked,
          version: result.post.version,
          updated_at: result.post.updated_at,
        });
      }

      this.editingPost = null;
      this.isSubmitting = false;
      return { ok: true };
    } catch (error) {
      this.isSubmitting = false;
      throw error;
    }
  }

  async #submitReply(raw) {
    const topic = this.args.topic;
    const postStream = topic.postStream;
    const user = this.currentUser;

    this.isSubmitting = true;

    const createdPost = this.store.createRecord("post", {
      raw,
      topic_id: topic.id,
      reply_to_post_number: this.replyingToPost?.post_number,
      nested_post: true,
      draft_key: topic.draft_key,
      reply_count: 0,
      name: user.name,
      display_username: user.name,
      username: user.username,
      user_id: user.id,
      user_title: user.title,
      avatar_template: user.avatar_template,
      user_custom_fields: user.custom_fields,
      post_type: this.site.post_types.regular,
      actions_summary: [],
      moderator: user.moderator,
      admin: user.admin,
      yours: true,
      read: true,
      wiki: false,
    });

    if (this.replyingToPost) {
      createdPost.setProperties({
        reply_to_post_number: this.replyingToPost.post_number,
        reply_to_user: {
          username: this.replyingToPost.username,
          avatar_template: this.replyingToPost.avatar_template,
        },
      });
    }

    const state = postStream.stagePost(createdPost, user);
    if (state === "alreadyStaging") {
      this.isSubmitting = false;
      return false;
    }

    try {
      await createdPost.save();
      postStream.commitPost(createdPost);
      topic.set("posts_count", (topic.posts_count || 0) + 1);

      if (this.replyingToPost) {
        this.replyingToPost.setProperties({
          reply_count: (this.replyingToPost.reply_count || 0) + 1,
          replies: [],
        });
      }

      this.replyingToPost = null;
      this.isSubmitting = false;
      return { ok: true };
    } catch (error) {
      postStream.undoPost(createdPost);
      this.isSubmitting = false;
      throw error;
    }
  }

  <template>
    {{#if this.showSigninCta}}
      <div class="embed-mode-composer embed-mode-composer--signin-cta">
        <DButton
          @action={{this.handleSigninCtaClick}}
          @label="embed_mode.signin_flow.sign_in_to_reply"
          class="btn-primary embed-mode-composer__signin-cta"
        />
      </div>
    {{else if this.show}}
      <div class="embed-mode-composer" {{this.setupEvents}}>
        {{#if this.showFloatingTimelineButton}}
          <div class="embed-floating-buttons">
            <DButton
              @action={{this.handleTimelineToggle}}
              @icon="bars-staggered"
              @title="topic.progress.title"
              class="btn-default embed-floating-timeline-button"
            />
          </div>
        {{/if}}
        {{#if this.editingPost}}
          <div class="embed-mode-composer__editing">
            <span class="embed-mode-composer__editing-text">
              {{dAvatar this.editingPost imageSize="tiny"}}
              {{i18n "embed_mode.editing_post"}}
            </span>
            <DButton
              @icon="xmark"
              @action={{this.cancelEditing}}
              class="btn-transparent embed-mode-composer__editing-dismiss"
            />
          </div>
        {{else if this.replyingToPost}}
          <div class="embed-mode-composer__replying-to">
            <span class="embed-mode-composer__replying-to-text">
              {{dAvatar this.replyingToPost imageSize="tiny"}}
              {{i18n
                "embed_mode.replying_to"
                username=this.replyingToPost.username
              }}
            </span>
            <DButton
              @icon="xmark"
              @action={{this.clearReplyingTo}}
              class="btn-transparent embed-mode-composer__replying-to-dismiss"
            />
          </div>
        {{/if}}
        <DockedComposer
          @topicId={{@topic.id}}
          @categoryId={{@topic.category.id}}
          @onSubmit={{this.handleSubmit}}
          @onRegisterApi={{this.registerComposerApi}}
          @isSubmitting={{this.isSubmitting}}
          @resizable={{true}}
          @placeholder={{this.placeholder}}
          @draftKey={{this.draftKey}}
          @submitOnEnter={{false}}
          @bodyClassName="embed-docked-composer-open"
          @class="embed-mode-composer__composer"
        />
      </div>
    {{/if}}
  </template>
}

import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { registerDestructor } from "@ember/destroyable";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ComposerActionItemBuilder } from "discourse/lib/composer/action-items";
import { prioritizeNameFallback } from "discourse/lib/settings";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import {
  ADD_TRANSLATION,
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DTextField from "discourse/ui-kit/d-text-field";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class ComposerActions extends Component {
  @service composer;
  @service composerActionState;
  @service router;
  @service site;

  @tracked replyTargetInViewport = false;
  #observer = null;

  constructor() {
    super(...arguments);
    this.composerActionState.remember({ topic: this.topic, post: this.post });

    this.router.on("routeDidChange", this.refreshReplyTargetObserver);
    this.refreshReplyTargetObserver();

    registerDestructor(this, () => {
      this.router.off("routeDidChange", this.refreshReplyTargetObserver);
      this.#disconnectReplyTargetObserver();
    });
  }

  @action
  refreshReplyTargetObserver() {
    this.#disconnectReplyTargetObserver();

    const postId = this.post?.id;
    if (!postId || !this.isOnComposerTopic) {
      this.replyTargetInViewport = false;
      return;
    }

    requestAnimationFrame(() => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      const element = document.querySelector(
        `article[data-post-id="${postId}"]`
      );

      if (!element) {
        this.replyTargetInViewport = false;
        return;
      }

      this.#observer = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          this.replyTargetInViewport = entry.isIntersecting;
        }
      });
      this.#observer.observe(element);
    });
  }

  #disconnectReplyTargetObserver() {
    this.#observer?.disconnect();
    this.#observer = null;
  }

  get action() {
    return this.args.action;
  }

  get topic() {
    return this.args.topic;
  }

  get post() {
    return this.args.post;
  }

  get composerModel() {
    return this.args.composerModel;
  }

  get replyOptions() {
    return this.args.replyOptions;
  }

  get isEditing() {
    return this.action === EDIT;
  }

  get isInSlowMode() {
    return this.topic?.slow_mode_seconds > 0;
  }

  get isPrivateMessage() {
    return Boolean(
      this.composerModel?.privateMessage || this.topic?.isPrivateMessage
    );
  }

  @cached
  get templateData() {
    const { action: currentAction, isInSlowMode, isEditing } = this;
    if (this.composerModel) {
      get(this.composerModel, "tags");
      get(this.composerModel, "category");
      get(this.composerModel, "whisper");
      get(this.composerModel, "noBump");
      get(this.composerModel, "unlistTopic");
    }

    let iconName;
    if (currentAction === CREATE_TOPIC) {
      iconName = "far-pen-to-square";
    } else if (currentAction === PRIVATE_MESSAGE) {
      iconName = "envelope";
    } else if (currentAction === CREATE_SHARED_DRAFT) {
      iconName = "far-clipboard";
    } else if (isInSlowMode) {
      iconName = "hourglass-start";
    } else if (isEditing) {
      iconName = "pencil";
    } else if (currentAction === REPLY && this.composerModel?.whisper) {
      iconName = "far-eye-slash";
    } else {
      iconName = "share";
    }

    const availableActions = this._computeAvailableActions();

    return {
      icon: iconName,
      label: this._labelText(),
      actions: availableActions,
      hasActions: availableActions.length > 0,
    };
  }

  _labelText() {
    const pluginLabel = this.composerModel?.customizationFor("actionTitle");
    if (pluginLabel) {
      return pluginLabel;
    }

    const currentAction = this.action;
    if (currentAction === CREATE_TOPIC) {
      return i18n("composer.composer_actions.create_topic.label");
    }
    if (currentAction === PRIVATE_MESSAGE) {
      return i18n("composer.composer_actions.create_personal_message.label");
    }
    if (currentAction === CREATE_SHARED_DRAFT) {
      return i18n("composer.composer_actions.shared_draft.label");
    }
    if (currentAction === EDIT_SHARED_DRAFT) {
      return i18n("composer.edit_shared_draft");
    }
    if (currentAction === ADD_TRANSLATION) {
      return i18n("composer.translations.title");
    }
    if (currentAction === EDIT) {
      return i18n("composer.composer_actions.edit_post");
    }
    if (currentAction === REPLY) {
      const isReplyingToPost =
        this.post &&
        this.replyOptions?.userAvatar &&
        this.replyOptions?.userLink;

      if (isReplyingToPost) {
        return this._postDisplayName(this.post);
      }
      return this.isPrivateMessage
        ? i18n("composer.composer_actions.reply_to_message.trigger")
        : i18n("composer.composer_actions.reply_to_topic.trigger");
    }

    return i18n("composer.composer_actions.create_topic.label");
  }

  _postDisplayName(post) {
    const fallback = i18n("composer.composer_actions.unknown_user");
    if (!post) {
      return fallback;
    }
    if (post === this.post && this.replyOptions?.userLink?.anchor) {
      return this.replyOptions.userLink.anchor;
    }
    return prioritizeNameFallback(post.name, post.username) || fallback;
  }

  _computeAvailableActions() {
    this.composerActionState.remember({ topic: this.topic, post: this.post });

    const currentAction = this.action;
    const currentTopic = this.topic;
    const currentPost = this.post;

    const composerActionItemBuilder = new ComposerActionItemBuilder(
      this,
      currentAction,
      currentTopic,
      currentPost,
      this.replyOptions,
      this.composerModel
    );

    const composerActionItems = composerActionItemBuilder.build();

    return applyValueTransformer(
      "composer-actions-content",
      composerActionItems,
      {
        action: currentAction,
        topic: currentTopic,
        post: currentPost,
        composerModel: this.composerModel,
      }
    );
  }

  get hasToggles() {
    return (
      this.composer.canToggleWhisper ||
      this.composer.canToggleNoBump ||
      this.composer.canUnlistTopic
    );
  }

  get hasMenuContent() {
    return this.templateData.hasActions || this.hasToggles;
  }

  get replyTargetHref() {
    if (this.action !== REPLY) {
      return null;
    }

    const options = this.replyOptions;
    if (this.post && options?.postLink) {
      return options.postLink.href;
    }
    if (options?.topicLink) {
      return options.topicLink.href;
    }
    return null;
  }

  get isOnComposerTopic() {
    const composerTopicId = this.composerModel?.topic?.id;
    if (!composerTopicId) {
      return false;
    }

    let route = this.router.currentRoute;
    while (route) {
      if (route.name === "topic") {
        return parseInt(route.params?.id, 10) === composerTopicId;
      }
      route = route.parent;
    }
    return false;
  }

  get isReplyTargetOnScreen() {
    return this.replyTargetInViewport;
  }

  get replyTargetLabel() {
    if (this.post) {
      return this.replyOptions?.postLink?.anchor;
    }
    if (this.isOnComposerTopic && !this.site.mobileView) {
      return null;
    }
    return (
      this.composerModel?.topic?.title || this.replyOptions?.topicLink?.anchor
    );
  }

  get showReplyTargetLink() {
    if (!this.replyTargetHref) {
      return false;
    }

    if (this.site.mobileView) {
      return true;
    }

    if (this.post) {
      return !this.isReplyTargetOnScreen;
    }

    return !this.isOnComposerTopic;
  }

  get replyTargetTitle() {
    if (this.post) {
      return i18n("composer.composer_actions.reply_to_post.label", {
        postUsername: this._postDisplayName(this.post),
        postNumber: this.post.post_number,
      });
    }
    return this.isPrivateMessage
      ? i18n("composer.composer_actions.reply_to_message.label")
      : i18n("composer.composer_actions.reply_to_topic.label");
  }

  @action
  toggleWhisper() {
    this.composerModel.toggleProperty("whisper");
  }

  @action
  runToggleAction(actionFn, event) {
    event.preventDefault();
    actionFn();
  }

  @action
  registerDmenuApi(api) {
    this.dmenuApi = api;
  }

  @action
  async onSelectAction(actionId) {
    await this.dmenuApi?.close({ focusTrigger: true });

    const options = this.composerModel.getProperties(
      "draftKey",
      "draftSequence",
      "title",
      "reply",
      "disableScopedCategory",
      "whisper",
      "noBump",
      "unlistTopic"
    );

    this.composerActionState.remember({ topic: this.topic, post: this.post });

    const handled = await this.composerActionState.selectAction(actionId, {
      options,
      composerModel: this.composerModel,
      topic: this.topic,
      post: this.post,
    });

    if (!handled) {
      applyBehaviorTransformer("composer-actions-on-select", () => {}, {
        actionId,
        options,
        model: this.composerModel,
      });
    }
  }

  <template>
    {{#let this.templateData as |data|}}
      {{#if this.hasMenuContent}}
        <DMenu
          @label={{data.label}}
          @icon={{data.icon}}
          @modalForMobile={{true}}
          @closeOnClickOutside={{true}}
          @closeOnEscape={{true}}
          @onRegisterApi={{this.registerDmenuApi}}
          @triggerClass="composer-actions-trigger btn-flat btn-icon-text"
          @contentClass="composer-actions-dropdown"
          class="composer-actions-new"
        >
          <:trigger>
            {{dIcon "angle-down" class="composer-actions-caret"}}
          </:trigger>

          <:content>
            <DDropdownMenu as |dropdown|>
              {{#each data.actions key="id" as |availAction|}}
                {{#unless availAction.isToggle}}
                  <dropdown.item>
                    <DButton
                      class="composer-actions-btn
                        {{if availAction.description '--with-description'}}"
                      @action={{fn this.onSelectAction availAction.id}}
                      data-action-id={{availAction.id}}
                    >
                      <div class="composer-actions-btn__icons">
                        {{dIcon availAction.icon}}
                      </div>
                      <div class="composer-actions-btn__texts">
                        <span class="composer-actions-btn__label">
                          {{availAction.name}}
                        </span>
                        <span class="composer-actions-btn__description">
                          {{availAction.description}}
                        </span>
                      </div>
                    </DButton>
                  </dropdown.item>
                {{/unless}}
              {{/each}}
              {{#unless (or data.actions.length this.hasToggles)}}
                <div class="composer-actions-btn">
                  {{i18n "composer.composer_actions.no_actions_available"}}
                </div>
              {{/unless}}

              {{#if this.hasToggles}}
                <dropdown.divider />
                <div class="composer-actions-toggles">
                  {{#each data.actions key="id" as |availAction|}}
                    {{#if availAction.isToggle}}
                      <dropdown.item>
                        {{! eslint-disable-next-line ember/template-no-invalid-interactive }}
                        <div
                          class={{dConcatClass
                            availAction.class
                            "composer-toggle-item --with-description btn"
                          }}
                          {{on
                            "click"
                            (fn this.runToggleAction availAction.action)
                          }}
                        >
                          <div class="composer-toggle-item__icons">
                            <DToggleSwitch
                              @state={{availAction.state}}
                              aria-label={{availAction.ariaLabel}}
                            />
                          </div>
                          <div class="composer-toggle-item__texts">
                            <span
                              class="composer-toggle-item__label"
                            >{{availAction.label}}</span>
                            <span
                              class="composer-toggle-item__description"
                            >{{availAction.description}}</span>
                          </div>

                        </div>
                      </dropdown.item>
                    {{/if}}
                  {{/each}}
                </div>
              {{/if}}
            </DDropdownMenu>
          </:content>
        </DMenu>

        {{#if this.showReplyTargetLink}}
          <a
            class={{dConcatClass
              "composer-actions-reply-target-link btn btn-transparent"
              (if this.replyTargetLabel "btn-icon-text" "btn-icon no-text")
              (if this.site.mobileView "btn-small")
            }}
            href={{this.replyTargetHref}}
            title={{this.replyTargetTitle}}
            aria-label={{this.replyTargetTitle}}
          >
            {{dIcon "link"}}
            {{#if this.replyTargetLabel}}
              <span
                class="d-button-label composer-actions-reply-target-link__label"
              >{{this.replyTargetLabel}}</span>
            {{/if}}
          </a>
        {{/if}}
      {{else if this.composer.showEditReason}}
        <span
          class="composer-actions-trigger composer-actions-trigger--static composer-actions-trigger--editing"
        >
          <DTextField
            @value={{this.composer.editReason}}
            @id="edit-reason"
            @maxlength="255"
            @placeholderKey="composer.edit_reason_placeholder"
            {{dAutoFocus}}
          />
        </span>
      {{else if this.composer.canEdit}}
        <DButton
          @action={{this.composer.displayEditReason}}
          @icon={{data.icon}}
          @label="composer.edit_reason"
          class="composer-actions-trigger composer-actions-trigger--static btn-transparent btn-icon-text"
        />
      {{else}}
        <span class="composer-actions-trigger composer-actions-trigger--static">
          {{dIcon data.icon}}
          <span class="d-button-label">{{data.label}}</span>
        </span>
      {{/if}}

      {{#if this.composer.canToggleWhisper}}
        <DButton
          @action={{this.toggleWhisper}}
          @icon={{if this.composerModel.whisper "far-eye-slash" "far-eye"}}
          @label={{if
            this.composerModel.whisper
            "composer.whisper_indicator.whispering"
            "composer.whisper_indicator.public"
          }}
          class={{dConcatClass
            "composer-whisper-indicator btn-transparent"
            (if this.composerModel.whisper "--whispering" "--public")
            (if this.site.mobileView "btn-small")
          }}
        />
      {{/if}}
    {{/let}}
  </template>
}

import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import DMenu from "discourse/float-kit/components/d-menu";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import { escapeExpression } from "discourse/lib/utilities";
import {
  ADD_TRANSLATION,
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// Separate snapshots for new component validation
let _topicSnapshot = null;
let _postSnapshot = null;
let _actionSnapshot = null;

export function _clearSnapshots() {
  _topicSnapshot = null;
  _postSnapshot = null;
  _actionSnapshot = null;
}

export default class ComposerActions extends Component {
  @service dialog;
  @service composer;
  @service currentUser;
  @service site;

  constructor() {
    super(...arguments);
    // Initialize snapshots on construction (safe - not during render)
    this.initializeSnapshots();
  }

  willDestroy() {
    super.willDestroy();
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

  initializeSnapshots() {
    // Initialize snapshots without triggering reactivity
    if (this.topic) {
      if (!_topicSnapshot || this.topic.id !== _topicSnapshot.id) {
        _topicSnapshot = this.topic;
        _postSnapshot = this.post;
      }
    } else {
      // Composer opened without a source topic (e.g. fresh "new topic" from
      // /latest); clear any snapshots left over from a previous reply session.
      _topicSnapshot = null;
      _postSnapshot = null;
    }

    if (this.post && (!_postSnapshot || this.post.id !== _postSnapshot.id)) {
      _postSnapshot = this.post;
    }

    if (this.action !== _actionSnapshot) {
      _actionSnapshot = this.action;
    }
  }

  ensureSnapshotsUpdated() {
    // Update snapshots silently (no seq increment to avoid loops)
    if (this.topic) {
      if (!_topicSnapshot || this.topic.id !== _topicSnapshot.id) {
        _topicSnapshot = this.topic;
        _postSnapshot = this.post;
      }
    } else {
      _topicSnapshot = null;
      _postSnapshot = null;
    }

    if (this.post && (!_postSnapshot || this.post.id !== _postSnapshot.id)) {
      _postSnapshot = this.post;
    }

    if (this.action !== _actionSnapshot) {
      _actionSnapshot = this.action;
    }
  }

  @cached
  get templateData() {
    const { action: currentAction, isInSlowMode, isEditing } = this;
    if (this.composerModel) {
      get(this.composerModel, "tags");
      get(this.composerModel, "category");
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
    } else {
      iconName = "share";
    }

    let labelText = this.composerModel?.customizationFor("actionTitle");
    if (labelText) {
      // plugin-provided label wins
    } else if (currentAction === CREATE_TOPIC) {
      labelText = i18n("composer.composer_actions.create_topic.label");
    } else if (currentAction === PRIVATE_MESSAGE) {
      labelText = i18n(
        "composer.composer_actions.create_personal_message.label"
      );
    } else if (currentAction === CREATE_SHARED_DRAFT) {
      labelText = i18n("composer.composer_actions.shared_draft.label");
    } else if (currentAction === EDIT_SHARED_DRAFT) {
      labelText = i18n("composer.edit_shared_draft");
    } else if (currentAction === ADD_TRANSLATION) {
      labelText = i18n("composer.translations.title");
    } else if (currentAction === REPLY) {
      const isReplyingToPost =
        this.post &&
        this.replyOptions?.userAvatar &&
        this.replyOptions?.userLink;

      if (isInSlowMode) {
        labelText = i18n("composer.composer_actions.slow_mode_reply");
      } else if (isReplyingToPost) {
        labelText = i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: this.post.username,
        });
      } else {
        labelText = i18n("composer.composer_actions.reply_to_topic.label");
      }
    } else if (currentAction === EDIT) {
      labelText = i18n("composer.composer_actions.edit_post");
    } else {
      labelText = i18n("composer.composer_actions.create_topic.label");
    }

    const availableActions = this._computeAvailableActions();

    return {
      icon: iconName,
      label: labelText,
      actions: availableActions,
      hasActions: availableActions.length > 0,
    };
  }

  _computeAvailableActions() {
    let items = [];

    const currentTopic = this.topic;
    const currentPost = this.post;
    const currentAction = this.action;

    // 1. Reply as New Topic (reply_as_new_topic)
    if (
      currentAction === REPLY &&
      currentAction !== CREATE_TOPIC &&
      currentAction !== CREATE_SHARED_DRAFT &&
      currentTopic &&
      !currentTopic.isPrivateMessage &&
      !this.isEditing &&
      this.currentUser?.can_create_topic &&
      currentTopic.id
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_as_new_topic.label"),
        description: i18n("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "far-pen-to-square",
        id: "reply_as_new_topic",
      };

      items.push(actionObj);
    }

    // 2. Reply to Post (reply_to_post)
    const canRestoreReplyToPost =
      currentAction === REPLY &&
      !currentPost &&
      _postSnapshot &&
      _topicSnapshot &&
      currentTopic?.id === _topicSnapshot.id;

    if (
      (currentAction !== REPLY && currentPost) ||
      (currentAction === REPLY &&
        currentPost &&
        !(this.replyOptions?.userAvatar && this.replyOptions?.userLink)) ||
      canRestoreReplyToPost
    ) {
      const postForLabel = currentPost || _postSnapshot;
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: postForLabel?.username || "User",
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };

      items.push(actionObj);
    }

    // 2.5. Reply to Topic (reply_to_topic) - show when user is currently replying to a specific post
    // Excludes CREATE_TOPIC and PRIVATE_MESSAGE modes which have their own reply_to_topic sections
    if (
      !this.isEditing &&
      currentAction !== CREATE_TOPIC &&
      currentAction !== PRIVATE_MESSAGE &&
      ((currentAction !== REPLY && currentTopic) ||
        (currentAction === REPLY &&
          currentTopic &&
          this.replyOptions?.userAvatar &&
          this.replyOptions?.userLink &&
          this.replyOptions?.topicLink))
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_topic.label"),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      };

      items.push(actionObj);
    }

    // === CREATE_TOPIC MODE ACTIONS ===

    // 2b. Reply to Post (when in CREATE_TOPIC mode with a remembered post)
    if (
      currentAction === CREATE_TOPIC &&
      !this.isEditing &&
      _postSnapshot &&
      _topicSnapshot
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: _postSnapshot.username || "User",
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };

      items.push(actionObj);
    }

    // 3. Reply to Topic (when in CREATE_TOPIC mode, allow going back to REPLY)
    if (currentAction === CREATE_TOPIC && !this.isEditing && _topicSnapshot) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_topic.label"),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      };

      items.push(actionObj);
    }

    // 4. Shared Draft (shared_draft) - CREATE_TOPIC MODE ONLY
    if (currentAction === CREATE_TOPIC && this.site.shared_drafts_category_id) {
      const actionObj = {
        name: i18n("composer.composer_actions.shared_draft.label"),
        description: i18n("composer.composer_actions.shared_draft.desc"),
        icon: "far-clipboard",
        id: "shared_draft",
      };

      items.push(actionObj);
    }

    // 7. Create Private Message (create_private_message) - CREATE_TOPIC MODE
    if (
      this.currentUser?.can_send_private_messages &&
      currentAction === CREATE_TOPIC &&
      !this.isEditing
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.create_personal_message.label"),
        description: i18n(
          "composer.composer_actions.create_personal_message.desc"
        ),
        icon: "envelope",
        id: "create_private_message",
      };

      items.push(actionObj);
    }

    // === PRIVATE_MESSAGE MODE ACTIONS ===

    // 8. Reply to Topic (when in PRIVATE_MESSAGE mode, allow going back to REPLY)
    if (
      currentAction === PRIVATE_MESSAGE &&
      !this.isEditing &&
      _topicSnapshot
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_topic.label"),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      };

      items.push(actionObj);
    }

    // 9. Create Topic (when in PRIVATE_MESSAGE mode, allow switching to CREATE_TOPIC)
    if (
      currentAction === PRIVATE_MESSAGE &&
      this.currentUser?.can_create_topic &&
      !this.isEditing
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.create_topic.label"),
        description: i18n("composer.composer_actions.create_topic.desc"),
        icon: "far-pen-to-square",
        id: "create_topic",
      };

      items.push(actionObj);
    }

    return applyValueTransformer("composer-actions-content", items, {
      action: currentAction,
      topic: currentTopic,
      post: currentPost,
      composerModel: this.composerModel,
    });
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
      "disableScopedCategory"
    );

    const composerAction = `${camelize(actionId)}Selected`;
    if (this[composerAction]) {
      this[composerAction](options, this.composerModel);
    } else {
      applyBehaviorTransformer("composer-actions-on-select", () => {}, {
        actionId,
        options,
        model: this.composerModel,
      });
    }
  }

  _continuedFromText(post, topic) {
    let url = post?.url || topic?.url;
    const topicTitle = topic?.title;

    if (!url || !topicTitle) {
      return;
    }

    url = `${location.protocol}//${location.host}${url}`;
    const link = `[${escapeExpression(topicTitle)}](${url})`;
    return i18n("post.continue_discussion", {
      postLink: link,
    });
  }

  async _replyFromExisting(options, post, topic) {
    await this.composer.destroyDraft();
    this.composer.close();
    await this.composer.open({
      ...options,
      prependText: this._continuedFromText(post, topic),
    });
  }

  _openComposer(options) {
    this.composer.closeComposer();
    this.composer.open(options);
  }

  replyAsNewTopicSelected(options) {
    Draft.get("new_topic").then((response) => {
      if (response.draft) {
        this.dialog.confirm({
          message: i18n("composer.composer_actions.reply_as_new_topic.confirm"),
          confirmButtonLabel: "composer.ok_proceed",
          didConfirm: () => this._replyAsNewTopicSelect(options),
        });
      } else {
        this._replyAsNewTopicSelect(options);
      }
    });
  }

  _replyAsNewTopicSelect(options) {
    options.action = CREATE_TOPIC;
    options.draftKey = this.composer.topicDraftKey;
    options.categoryId = this.composerModel.topic?.category?.id;
    options.disableScopedCategory = true;
    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  }

  replyToPostSelected(options) {
    options.action = REPLY;
    options.post = _postSnapshot;
    this._openComposer(options);
  }

  replyToTopicSelected(options) {
    options.action = REPLY;
    options.topic = _topicSnapshot;
    this._openComposer(options);
  }

  _switchCreate(options, composerAction) {
    options.action = composerAction;
    options.categoryId = this.composerModel.categoryId;
    options.topicTitle = this.composerModel.title;
    options.tags = this.composerModel.tags;
    this._openComposer(options);
  }

  sharedDraftSelected(options) {
    this._switchCreate(options, CREATE_SHARED_DRAFT);
  }

  createTopicSelected(options) {
    this._switchCreate(options, CREATE_TOPIC);
  }

  createPrivateMessageSelected(options) {
    options.archetypeId = "private_message";
    this._switchCreate(options, PRIVATE_MESSAGE);
  }

  <template>
    {{#let this.templateData as |data|}}

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
            {{#each data.actions as |availAction|}}
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
            {{/each}}
            {{#unless data.actions.length}}
              <div class="composer-actions-btn">
                No actions available
              </div>
            {{/unless}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/let}}
  </template>
}

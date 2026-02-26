import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import DMenu from "discourse/float-kit/components/d-menu";
import icon from "discourse/helpers/d-icon";
import { escapeExpression } from "discourse/lib/utilities";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import Draft from "discourse/models/draft";
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

  get whisper() {
    return this.args.whisper;
  }

  get noBump() {
    return this.args.noBump;
  }

  get composerModel() {
    return this.args.composerModel;
  }

  get replyOptions() {
    return this.args.replyOptions;
  }

  get canWhisper() {
    return this.args.canWhisper;
  }

  get canUnlistTopic() {
    return this.args.canUnlistTopic;
  }

  get isEditing() {
    return this.action === EDIT;
  }

  get isInSlowMode() {
    return this.topic?.slow_mode_seconds > 0;
  }

  initializeSnapshots() {
    // Initialize snapshots without triggering reactivity
    if (
      this.topic &&
      (!_topicSnapshot || this.topic.id !== _topicSnapshot.id)
    ) {
      _topicSnapshot = this.topic;
      _postSnapshot = this.post;
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
    if (
      this.topic &&
      (!_topicSnapshot || this.topic.id !== _topicSnapshot.id)
    ) {
      _topicSnapshot = this.topic;
      _postSnapshot = this.post;
    }

    if (this.post && (!_postSnapshot || this.post.id !== _postSnapshot.id)) {
      _postSnapshot = this.post;
    }

    if (this.action !== _actionSnapshot) {
      _actionSnapshot = this.action;
    }
  }

  // Single cached getter for all template data to prevent reactivity cycles
  @cached
  get templateData() {
    // First compute icon and label
    const {
      action: currentAction,
      whisper,
      noBump,
      isInSlowMode,
      isEditing,
    } = this;

    let iconName;
    if (currentAction === CREATE_TOPIC) {
      iconName = "plus";
    } else if (currentAction === PRIVATE_MESSAGE) {
      iconName = "envelope";
    } else if (currentAction === CREATE_SHARED_DRAFT) {
      iconName = "far-clipboard";
    } else if (whisper) {
      iconName = "far-eye-slash";
    } else if (noBump) {
      iconName = "anchor";
    } else if (isInSlowMode) {
      iconName = "hourglass-start";
    } else if (isEditing) {
      iconName = "pencil";
    } else {
      iconName = "share";
    }

    let labelText;
    if (currentAction === CREATE_TOPIC) {
      if (this.canUnlistTopic && this.composerModel?.unlistTopic) {
        labelText = i18n("composer.composer_actions.create_unlisted_topic");
      } else {
        labelText = i18n("composer.composer_actions.create_topic.label");
      }
    } else if (currentAction === PRIVATE_MESSAGE) {
      labelText = i18n(
        "composer.composer_actions.create_personal_message.label"
      );
    } else if (currentAction === CREATE_SHARED_DRAFT) {
      labelText = i18n("composer.composer_actions.shared_draft.label");
    } else if (currentAction === REPLY) {
      if (whisper) {
        labelText = i18n("composer.composer_actions.toggle_whisper.label");
      } else if (noBump) {
        labelText = i18n("composer.composer_actions.toggle_topic_bump.label");
      } else if (isInSlowMode) {
        labelText = i18n("composer.composer_actions.slow_mode_reply");
      } else {
        labelText = i18n(
          "composer.composer_actions.reply_to_topic_composer_action.label"
        );
      }
    } else if (currentAction === EDIT) {
      labelText = i18n("composer.composer_actions.edit_post");
    } else {
      labelText = i18n("composer.composer_actions.create_topic.label");
    }

    // Now compute available actions
    const availableActions = this._computeAvailableActions();

    return {
      icon: iconName,
      label: labelText,
      actions: availableActions,
      hasActions: availableActions.length > 0,
    };
  }

  // Focus on just the 3 reply actions for now
  _computeAvailableActions() {
    let items = [];

    // Use current args instead of snapshots for stability during rendering
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
      currentTopic.id // Use current topic instead of snapshot during rendering
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_as_new_topic.label"),
        description: i18n("composer.composer_actions.reply_as_new_topic.desc"),
        icon: "plus",
        id: "reply_as_new_topic",
      };

      items.push(actionObj);
    }

    // 2. Reply to Post (reply_to_post)
    if (
      (currentAction !== REPLY && currentPost) ||
      (currentAction === REPLY &&
        currentPost &&
        !(this.replyOptions?.userAvatar && this.replyOptions?.userLink))
    ) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_post.label", {
          postUsername: currentPost?.username || "User",
        }),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };

      items.push(actionObj);
    }

    // 2.5. Reply to Topic (reply_to_topic) - show when user is currently replying to a specific post
    if (
      !this.isEditing &&
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

    // 3. Toggle Topic Bump (toggle_topic_bump) - REPLY MODE ONLY
    const showToggleTopicBump =
      this.currentUser?.staff || this.currentUser?.trust_level === 4;
    if (currentAction === REPLY && showToggleTopicBump) {
      const actionObj = {
        name: i18n("composer.composer_actions.toggle_topic_bump.label"),
        description: i18n("composer.composer_actions.toggle_topic_bump.desc"),
        icon: "anchor",
        id: "toggle_topic_bump",
      };

      items.push(actionObj);
    }

    // === CREATE_TOPIC MODE ACTIONS ===

    // 4. Reply to Topic (when in CREATE_TOPIC mode, allow going back to REPLY)
    if (currentAction === CREATE_TOPIC && !this.isEditing && _topicSnapshot) {
      const actionObj = {
        name: i18n("composer.composer_actions.reply_to_topic.label"),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      };

      items.push(actionObj);
    }

    // 5. Toggle Unlisted (for CREATE_TOPIC mode)
    if (currentAction === CREATE_TOPIC && this.canUnlistTopic) {
      const actionObj = {
        name: i18n("composer.composer_actions.toggle_unlisted.label"),
        description: i18n("composer.composer_actions.toggle_unlisted.desc"),
        icon: "far-eye-slash",
        id: "toggle_unlisted",
      };

      items.push(actionObj);
    }

    // 6. Shared Draft (shared_draft) - CREATE_TOPIC MODE ONLY
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
        icon: "share",
        id: "create_topic",
      };

      items.push(actionObj);
    }

    return items;
  }

  @action
  async onSelectAction(actionId) {
    // EXACT method dispatch pattern from original
    const composerAction = `${camelize(actionId)}Selected`;
    if (this[composerAction]) {
      this[composerAction](
        this.composerModel.getProperties(
          "draftKey",
          "draftSequence",
          "title",
          "reply",
          "disableScopedCategory"
        ),
        this.composerModel
      );
    }
  }

  // Action methods - preserve exact logic from original

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

  toggleTopicBumpSelected(options, model) {
    model.toggleProperty("noBump");
  }

  toggleUnlistedSelected(options, model) {
    model.toggleProperty("unlistTopic");
  }

  // === TEMPORARY: CREATE_TOPIC MODE ACTION METHODS ===

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
        @triggerClass="composer-actions-trigger btn-flat btn-icon-text"
        @contentClass="composer-actions-dropdown"
        class="composer-actions-new"
      >
        <:trigger>
          {{icon "angle-down" class="composer-actions-caret"}}
        </:trigger>

        <:content>
          <DropdownMenu as |dropdown|>
            {{#each data.actions as |availAction|}}
              <dropdown.item>
                <DButton
                  class="composer-actions-btn
                    {{if availAction.description '--with-description'}}"
                  @action={{fn this.onSelectAction availAction.id}}
                  data-action-id={{availAction.id}}
                >
                  <div class="composer-actions-btn__icons">
                    {{icon availAction.icon}}
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
              <div class="composer-actions-empty">
                No actions available
              </div>
            {{/unless}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{/let}}
  </template>
}

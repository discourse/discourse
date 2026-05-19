import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, get } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import { trustHTML } from "@ember/template";
import DMenu from "discourse/float-kit/components/d-menu";
import { prioritizeNameFallback } from "discourse/lib/settings";
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
import DTextField from "discourse/ui-kit/d-text-field";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
    this.ensureSnapshotsUpdated();
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

  // Mirrors the original composer-actions.js didReceiveAttrs behaviour: only
  // update snapshots when this.topic / this.post are present and changed. Do
  // NOT clear snapshots when this.topic becomes null — module-level snapshots
  // are intentionally session-scoped so that flows like reply_as_new_topic
  // (which switch to CREATE_TOPIC with a null this.topic) can still surface
  // "Reply to topic" / "Reply to post" as a way back. Tests reset snapshots
  // between runs via _clearSnapshots in qunit-helpers.js.
  //
  // Safe to call from getters: the snapshot vars are plain (not @tracked), so
  // mutating them does not trigger re-renders. Called from the constructor,
  // from _computeAvailableActions() before each render, and defensively at
  // the top of selection handlers in case args drift between menu render and
  // click.
  ensureSnapshotsUpdated() {
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

  @cached
  get templateData() {
    const { action: currentAction, isInSlowMode, isEditing } = this;
    if (this.composerModel) {
      get(this.composerModel, "tags");
      get(this.composerModel, "category");
      get(this.composerModel, "whisper");
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
        labelText = this._replyToPostLabel(this._postDisplayName(this.post));
      } else {
        labelText = this._replyToTopicLabel();
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

  _postDisplayName(post) {
    if (!post) {
      return "User";
    }
    if (post === this.post && this.replyOptions?.userLink?.anchor) {
      return this.replyOptions.userLink.anchor;
    }
    return prioritizeNameFallback(post.name, post.username) || "User";
  }

  // Builds the "Reply to a post by <user>" label as trusted HTML with span
  // wrappers so CSS can target / hide the prefix on small viewports while
  // keeping the username visible.
  _replyToPostLabel(username) {
    const prefix = escapeExpression(
      i18n("composer.composer_actions.reply_to_post.label_prefix")
    );
    const user = escapeExpression(username || "");
    return trustHTML(
      `<span class="composer-action-label__prefix">${prefix}</span> ` +
        `<span class="composer-action-label__user">${user}</span>`
    );
  }

  // Same split treatment as _replyToPostLabel so CSS can hide the prefix on
  // small viewports while keeping the noun visible.
  _replyToTopicLabel() {
    const prefix = escapeExpression(
      i18n("composer.composer_actions.reply_to_topic.label_prefix")
    );
    const noun = escapeExpression(
      i18n("composer.composer_actions.reply_to_topic.label_noun")
    );
    return trustHTML(
      `<span class="composer-action-label__prefix">${prefix}</span> ` +
        `<span class="composer-action-label__topic">${noun}</span>`
    );
  }

  _computeAvailableActions() {
    // Refresh module-level snapshots against current args before deciding
    // which actions to expose. Without this, a composer instance that was
    // first constructed in REPLY mode but later retargeted to a fresh
    // CREATE_TOPIC (this.topic === null) would still show snapshot-backed
    // reply_to_post / reply_to_topic items, and selecting one would open
    // REPLY with a null topic once the handler clears the snapshots.
    this.ensureSnapshotsUpdated();

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

    // 1b. Reply as New Group Message (reply_as_new_group_message) - PM with
    // multiple recipients or any group recipient
    if (
      currentAction === REPLY &&
      !this.isEditing &&
      currentTopic?.isPrivateMessage &&
      currentTopic.details &&
      (currentTopic.details.allowed_users?.length > 1 ||
        currentTopic.details.allowed_groups?.length > 0)
    ) {
      const actionObj = {
        name: i18n(
          "composer.composer_actions.reply_as_new_group_message.label"
        ),
        description: i18n(
          "composer.composer_actions.reply_as_new_group_message.desc"
        ),
        icon: "plus",
        id: "reply_as_new_group_message",
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
      !this.isEditing &&
      ((currentAction !== REPLY && currentPost) ||
        (currentAction === REPLY &&
          currentPost &&
          !(this.replyOptions?.userAvatar && this.replyOptions?.userLink)) ||
        canRestoreReplyToPost)
    ) {
      const postForLabel = currentPost || _postSnapshot;
      const actionObj = {
        name: this._replyToPostLabel(this._postDisplayName(postForLabel)),
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
        name: this._replyToTopicLabel(),
        description: i18n("composer.composer_actions.reply_to_topic.desc"),
        icon: "share",
        id: "reply_to_topic",
      };

      items.push(actionObj);
    }

    // === CREATE_TOPIC / CREATE_SHARED_DRAFT MODE ACTIONS ===

    const inCreateTopicLike =
      currentAction === CREATE_TOPIC || currentAction === CREATE_SHARED_DRAFT;

    // 2b. Reply to Post (when in CREATE_TOPIC/CREATE_SHARED_DRAFT mode with a
    // remembered post)
    if (
      inCreateTopicLike &&
      !this.isEditing &&
      _postSnapshot &&
      _topicSnapshot
    ) {
      const actionObj = {
        name: this._replyToPostLabel(this._postDisplayName(_postSnapshot)),
        description: i18n("composer.composer_actions.reply_to_post.desc"),
        icon: "share",
        id: "reply_to_post",
      };

      items.push(actionObj);
    }

    // 3. Reply to Topic (allow going back to REPLY from
    // CREATE_TOPIC/CREATE_SHARED_DRAFT)
    if (inCreateTopicLike && !this.isEditing && _topicSnapshot) {
      const actionObj = {
        name: this._replyToTopicLabel(),
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

    // 5. Create Topic (when in CREATE_SHARED_DRAFT mode, allow switching back
    // to CREATE_TOPIC)
    if (
      currentAction === CREATE_SHARED_DRAFT &&
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

    // 7. Create Private Message (create_private_message) -
    // CREATE_TOPIC/CREATE_SHARED_DRAFT MODE
    if (
      this.currentUser?.can_send_private_messages &&
      inCreateTopicLike &&
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
        name: this._replyToTopicLabel(),
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

  get canToggleWhisper() {
    return (
      this.composer.canWhisper &&
      this.composerModel?.post?.post_type !== this.site.post_types?.whisper
    );
  }

  get canToggleNoBump() {
    return this.composer.canToggleNoBump;
  }

  get canUnlistTopic() {
    return this.composer.canUnlistTopic;
  }

  get hasToggles() {
    return this.canToggleWhisper || this.canToggleNoBump || this.canUnlistTopic;
  }

  get hasMenuContent() {
    return this.templateData.hasActions || this.hasToggles;
  }

  @action
  toggleWhisper() {
    this.composerModel.toggleProperty("whisper");
  }

  @action
  toggleNoBump() {
    this.composerModel.toggleProperty("noBump");
  }

  @action
  toggleUnlisted() {
    this.composerModel.toggleProperty("unlistTopic");
  }

  @action
  registerDmenuApi(api) {
    this.dmenuApi = api;
  }

  @action
  handleEditReasonClick() {
    this.composer.displayEditReason();
    schedule("afterRender", () => {
      document.getElementById("edit-reason")?.focus();
    });
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
    this._reapplyToggles(options);
  }

  async _openComposer(options) {
    this.composer.closeComposer();
    await this.composer.open(options);
    this._reapplyToggles(options);
  }

  // composer.open() / model.open() pick up `whisper` and `noBump` from opts but
  // not `unlistTopic`, so make sure all three toggle states survive a mode
  // switch (reply-to-topic <-> reply-to-post, etc.)
  _reapplyToggles(options) {
    const model = this.composer.model;
    if (!model) {
      return;
    }
    if (options.unlistTopic) {
      model.set("unlistTopic", true);
    }
    if (options.whisper) {
      model.set("whisper", true);
    }
    if (options.noBump) {
      model.set("noBump", true);
    }
  }

  replyAsNewGroupMessageSelected(options) {
    this.ensureSnapshotsUpdated();
    const recipients = [];
    const details = this.topic.details;
    details.allowed_users.forEach((u) => recipients.push(u.username));
    details.allowed_groups.forEach((g) => recipients.push(g.name));

    options.action = PRIVATE_MESSAGE;
    options.recipients = recipients.join(",");
    options.archetypeId = "private_message";

    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
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
    this.ensureSnapshotsUpdated();
    options.action = CREATE_TOPIC;
    options.draftKey = this.composer.topicDraftKey;
    options.categoryId = this.composerModel.topic?.category?.id;
    options.disableScopedCategory = true;
    this._replyFromExisting(options, _postSnapshot, _topicSnapshot);
  }

  replyToPostSelected(options) {
    this.ensureSnapshotsUpdated();
    options.action = REPLY;
    options.post = _postSnapshot;
    this._openComposer(options);
  }

  replyToTopicSelected(options) {
    this.ensureSnapshotsUpdated();
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
                  {{i18n "composer.composer_actions.no_actions_available"}}
                </div>
              {{/unless}}

              {{#if this.hasToggles}}
                <div class="composer-actions-toggles">
                  {{#if this.canToggleWhisper}}
                    <dropdown.item>
                      <DButton
                        class="composer-toggle-item composer-toggle-whisper --with-description"
                        @action={{this.toggleWhisper}}
                      >
                        <div class="composer-toggle-item__icons">
                          {{dIcon "far-eye-slash"}}
                        </div>
                        <div class="composer-toggle-item__texts">
                          <span class="composer-toggle-item__label">{{i18n
                              "composer.composer_actions.toggle_whisper.label"
                            }}</span>
                          <span class="composer-toggle-item__description">{{i18n
                              "composer.composer_actions.toggle_whisper.desc"
                            }}</span>
                        </div>
                        <DToggleSwitch @state={{this.composerModel.whisper}} />
                      </DButton>
                    </dropdown.item>
                  {{/if}}

                  {{#if this.canToggleNoBump}}
                    <dropdown.item>
                      <DButton
                        class="composer-toggle-item composer-toggle-no-bump --with-description"
                        @action={{this.toggleNoBump}}
                      >
                        <div class="composer-toggle-item__icons">
                          {{dIcon "anchor"}}
                        </div>
                        <div class="composer-toggle-item__texts">
                          <span class="composer-toggle-item__label">{{i18n
                              "composer.composer_actions.toggle_topic_bump.label"
                            }}</span>
                          <span class="composer-toggle-item__description">{{i18n
                              "composer.composer_actions.toggle_topic_bump.desc"
                            }}</span>
                        </div>
                        <DToggleSwitch @state={{this.composerModel.noBump}} />
                      </DButton>
                    </dropdown.item>
                  {{/if}}

                  {{#if this.canUnlistTopic}}
                    <dropdown.item>
                      <DButton
                        class="composer-toggle-item composer-toggle-unlisted --with-description"
                        @action={{this.toggleUnlisted}}
                      >
                        <div class="composer-toggle-item__icons">
                          {{dIcon "far-eye-slash"}}
                        </div>
                        <div class="composer-toggle-item__texts">
                          <span class="composer-toggle-item__label">{{i18n
                              "composer.composer_actions.toggle_unlisted.label"
                            }}</span>
                          <span class="composer-toggle-item__description">{{i18n
                              "composer.composer_actions.toggle_unlisted.desc"
                            }}</span>
                        </div>
                        <DToggleSwitch
                          @state={{this.composerModel.unlistTopic}}
                        />
                      </DButton>
                    </dropdown.item>
                  {{/if}}
                </div>
              {{/if}}
            </DDropdownMenu>
          </:content>
        </DMenu>
      {{else if this.composer.showEditReason}}
        <span
          class="composer-actions-trigger composer-actions-trigger--static composer-actions-trigger--editing"
        >
          <DTextField
            @value={{this.composer.editReason}}
            @id="edit-reason"
            @maxlength="255"
            @placeholderKey="composer.edit_reason_placeholder"
          />
        </span>
      {{else if this.composer.canEdit}}
        <DButton
          @action={{this.handleEditReasonClick}}
          @icon={{data.icon}}
          @label="composer.describe_your_edit"
          class="composer-actions-trigger composer-actions-trigger--static btn-flat btn-icon-text"
        />
      {{else}}
        <span class="composer-actions-trigger composer-actions-trigger--static">
          {{dIcon data.icon}}
          <span class="d-button-label">{{data.label}}</span>
        </span>
      {{/if}}

      {{#if this.canToggleWhisper}}
        <DButton
          @action={{this.toggleWhisper}}
          @icon={{if this.composerModel.whisper "far-eye-slash" "far-eye"}}
          @label={{if
            this.composerModel.whisper
            "composer.whisper_indicator.whispering"
            "composer.whisper_indicator.public"
          }}
          class={{dConcatClass
            "composer-whisper-indicator btn-flat"
            (if this.composerModel.whisper "--whispering" "--public")
          }}
        />
      {{/if}}
    {{/let}}
  </template>
}

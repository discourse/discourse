import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import FlagActionType from "discourse/components/flag-action-type";
import FlagSelection from "discourse/components/flag-selection";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableBundledAction from "discourse/components/reviewable-bundled-action";
import lazyHash from "discourse/helpers/lazy-hash";
import { reload } from "discourse/helpers/page-reloader";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

const NOTIFY_MODERATORS_KEY = "notify_moderators";

export default class Flag extends Component {
  @service adminTools;
  @service currentUser;
  @service siteSettings;
  @service site;
  @service appEvents;

  @tracked userDetails;
  @tracked selected;
  @tracked message;
  @tracked isConfirmed = false;
  @tracked isWarning = false;
  @tracked spammerDetails;

  constructor() {
    super(...arguments);

    this.adminTools
      ?.checkSpammer(this.args.model.flagModel.user_id)
      .then((result) => (this.spammerDetails = result));

    if (this.flagsAvailable.length === 1) {
      this.selected = this.flagsAvailable[0];
    }
  }

  get flagActions() {
    return {
      icon: "gavel",
      label: i18n("flagging.take_action"),
      actions: [
        {
          id: "agree_and_hide",
          icon: "thumbs-up",
          label: i18n("flagging.take_action_options.default.title"),
          description: i18n("flagging.take_action_options.default.details"),
        },
        {
          id: "agree_and_suspend",
          icon: "ban",
          label: i18n("flagging.take_action_options.suspend.title"),
          description: i18n("flagging.take_action_options.suspend.details"),
          client_action: "suspend",
        },
        {
          id: "agree_and_silence",
          icon: "microphone-slash",
          label: i18n("flagging.take_action_options.silence.title"),
          description: i18n("flagging.take_action_options.silence.details"),
          client_action: "silence",
        },
      ],
    };
  }

  get canSendWarning() {
    return (
      !this.args.model.flagTarget.targetsTopic() &&
      this.currentUser.staff &&
      this.selected?.name_key === "notify_user"
    );
  }

  get showDeleteSpammer() {
    return this.spammerDetails?.canDelete && this.selected?.name_key === "spam";
  }

  get submitLabel() {
    if (this.selected?.require_message) {
      return this.args.model.flagTarget.customSubmitLabel();
    }

    return this.args.model.flagTarget.submitLabel();
  }

  get title() {
    return this.args.model.flagTarget.title();
  }

  get flagsAvailable() {
    return this.args.model.flagTarget.flagsAvailable(this).filterBy("enabled");
  }

  get staffFlagsAvailable() {
    return this.flagsAvailable.length > 1;
  }

  get submitEnabled() {
    if (!this.selected) {
      return false;
    }

    if (!this.selected.require_message) {
      return true;
    }

    if (this.selected.isIllegal && !this.isConfirmed) {
      return false;
    }

    const len = this.message?.length || 0;
    return (
      len >= this.siteSettings.min_personal_message_post_length &&
      len <= MAX_MESSAGE_LENGTH
    );
  }

  get notifyModeratorsFlag() {
    return this.flagsAvailable.find((f) => f.id === NOTIFY_MODERATORS_KEY);
  }

  get canTakeAction() {
    return (
      !this.args.model.flagTarget.targetsTopic() &&
      !this.selected?.require_message &&
      this.currentUser.staff
    );
  }

  @action
  onKeydown(event) {
    if (
      this.submitEnabled &&
      event.key === "Enter" &&
      (event.ctrlKey || event.metaKey)
    ) {
      this.createFlag();
      return false;
    }
  }

  @action
  async penalize(adminToolMethod, performAction) {
    if (!this.adminTools) {
      return;
    }

    const createdBy = await User.findByUsername(
      this.args.model.flagModel.username
    );
    const opts = { before: performAction };

    if (this.args.model.flagTarget.editable()) {
      opts.postId = this.args.model.flagModel.id;
      opts.postEdit = this.args.model.flagModel.cooked;
    }

    return this.adminTools[adminToolMethod](createdBy, opts);
  }

  @action
  async deleteSpammer() {
    if (this.spammerDetails) {
      await this.spammerDetails.deleteUser();
      reload();
    }
  }

  @action
  async takeAction(actionable) {
    if (actionable.client_action === "suspend") {
      await this.penalize("showSuspendModal", () =>
        this.createFlag({ takeAction: true, skipClose: true })
      );
    } else if (actionable.client_action === "silence") {
      await this.penalize("showSilenceModal", () =>
        this.createFlag({ takeAction: true, skipClose: true })
      );
    } else if (actionable.client_action) {
      // eslint-disable-next-line no-console
      console.error(`No handler for ${actionable.client_action} found`);
    } else {
      this.args.model.setHidden();
      this.createFlag({ takeAction: true });
    }
  }

  @action
  createFlag(opts = {}) {
    if (this.selected.require_message) {
      opts.message = this.message;
    }
    this.args.model.flagTarget.create(this, opts);
    this.appEvents.trigger("flag:created", {
      message: opts.message,
      postId: this.args.model.flagModel.id,
    });
  }

  @action
  createFlagAsWarning() {
    this.createFlag({ isWarning: true });
    this.args.model.setHidden();
  }

  @action
  flagForReview() {
    this.selected ||= this.notifyModeratorsFlag;
    this.createFlag({ queue_for_review: true });
    this.args.model.setHidden();
  }

  @action
  changePostActionType(actionType) {
    this.selected = actionType;
  }

  <template>
    <DModal
      class="flag-modal"
      @bodyClass="flag-modal-body"
      @title={{i18n this.title}}
      @submitOnEnter={{false}}
      @closeModal={{@closeModal}}
      {{on "keydown" this.onKeydown}}
    >
      <:body>
        <p>{{htmlSafe (i18n "flagging.review_process_description")}}</p>
        <PluginOutlet
          @name="after-flag-modal-review-process-description"
          @connectorTagName="div"
          @outletArgs={{lazyHash post=@model.flagModel}}
        />
        <form>
          <FlagSelection
            @nameKey={{this.selected.name_key}}
            @flags={{this.flagsAvailable}}
            as |f|
          >
            <FlagActionType
              @flag={{f}}
              @message={{this.message}}
              @isConfirmed={{this.isConfirmed}}
              @isWarning={{this.isWarning}}
              @selectedFlag={{this.selected}}
              @username={{@model.flagModel.username}}
              @staffFlagsAvailable={{this.staffFlagsAvailable}}
              @changePostActionType={{this.changePostActionType}}
            />
          </FlagSelection>
        </form>
        <PluginOutlet
          @name="flag-modal-bottom"
          @connectorTagName="div"
          @outletArgs={{lazyHash post=@model.flagModel}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary flag-modal__create-flag"
          @action={{this.createFlag}}
          @disabled={{not this.submitEnabled}}
          @title="flagging.submit_tooltip"
          @icon={{if this.selected.is_custom_flag "envelope" "flag"}}
          @label={{this.submitLabel}}
        />

        {{#if this.canSendWarning}}
          <DButton
            class="btn-danger flag-modal__send-warning"
            @action={{this.createFlagAsWarning}}
            @disabled={{not this.submitEnabled}}
            @icon="triangle-exclamation"
            @label="flagging.official_warning"
          />
        {{/if}}

        {{#if this.canTakeAction}}
          <ReviewableBundledAction
            class="flag-modal__take-action"
            @bundle={{this.flagActions}}
            @performAction={{this.takeAction}}
            @reviewableUpdating={{not this.submitEnabled}}
          />

          <DButton
            class="btn-danger flag-modal__flag-for-review"
            @action={{this.flagForReview}}
            @disabled={{not this.submitEnabled this.notifyModeratorsFlag}}
            @icon="triangle-exclamation"
            @label="flagging.flag_for_review"
          />
        {{/if}}

        {{#if this.showDeleteSpammer}}
          <DButton
            class="btn-danger delete-spammer flag-modal__delete-spammer"
            @action={{this.deleteSpammer}}
            @disabled={{not this.submitEnabled}}
            @icon="triangle-exclamation"
            @label="flagging.delete_spammer"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}

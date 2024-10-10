import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, not } from "truth-helpers";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import { getNativeContact } from "discourse/lib/pwa-utils";
import { sanitize } from "discourse/lib/text";
import { emailValid, hostnameValid } from "discourse/lib/utilities";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";
import i18n from "discourse-common/helpers/i18n";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";
import GroupChooser from "select-kit/components/group-chooser";
import TopicChooser from "select-kit/components/topic-chooser";

export default class CreateInvite extends Component {
  @service currentUser;
  @service siteSettings;

  @tracked saving = false;
  @tracked displayAdvancedOptions = false;
  @tracked submitButton;

  @tracked flashText = null;
  @tracked flashClass = null;
  @tracked flashLink = false;

  @tracked topics = this.invite.topics ?? this.model.topics ?? [];
  @tracked allGroups = null;

  model = this.args.model;
  invite = this.model.invite ?? Invite.create();

  constructor() {
    super(...arguments);

    Group.findAll().then((groups) => {
      this.allGroups = groups.filterBy("automatic", false);
    });
  }

  get linkValidityMessageFormat() {
    return I18n.messageFormat("user.invited.invite.link_validity_MF", {
      user_count: this.maxRedemptionsAllowedLimit,
      duration_days: this.siteSettings.invite_expiry_days,
    });
  }

  get expireAfterOptions() {
    return [
      {
        value: 1,
        text: I18n.t("dates.medium.x_days", { count: 1 }),
      },
      {
        value: 7,
        text: I18n.t("dates.medium.x_days", { count: 7 }),
      },
      {
        value: 30,
        text: I18n.t("dates.medium.x_days", { count: 30 }),
      },
      {
        value: 90,
        text: I18n.t("dates.medium.x_days", { count: 90 }),
      },
      {
        value: 99999,
        text: I18n.t("time_shortcut.never"),
      },
    ];
  }

  get data() {
    return {
      restrictTo: this.invite.emailOrDomain ?? "",
      maxRedemptions:
        this.invite.max_redemptions_allowed ?? this.maxRedemptionsAllowedLimit,
      expireAfterDays:
        this.invite.expires_at ?? this.siteSettings.invite_expiry_days,
      inviteToTopic: this.invite.topicId,
      inviteToGroups: this.model.groupIds ?? this.invite.groupIds ?? [],
      customMessage: this.invite.custom_message ?? "",
    };
  }

  async save(data, opts) {
    let isLink = true;
    let isEmail = false;

    if (data.emailOrDomain) {
      if (emailValid(data.emailOrDomain)) {
        isEmail = true;
        isLink = false;
        data.email = data.emailOrDomain?.trim();
      } else if (hostnameValid(data.emailOrDomain)) {
        data.domain = data.emailOrDomain?.trim();
      }
      delete data.emailOrDomain;
    }

    if (data.groupIds !== undefined) {
      data.group_ids = data.groupIds.length > 0 ? data.groupIds : "";
      delete data.groupIds;
    }

    if (data.topicId !== undefined) {
      data.topic_id = data.topicId;
      delete data.topicId;
      delete data.topicTitle;
    }

    if (isLink) {
      if (this.invite.email) {
        data.email = data.custom_message = "";
      }
    } else if (isEmail) {
      if (data.max_redemptions_allowed > 1) {
        data.max_redemptions_allowed = 1;
      }

      if (opts.sendEmail) {
        data.send_email = true;

        // TODO: check what's up with this. nothing updates this property
        if (this.inviteToTopic) {
          data.invite_to_topic = true;
        }
      } else {
        data.skip_email = true;
      }
    }

    this.saving = true;
    try {
      await this.invite.save(data);
      const invites = this.model?.invites;
      if (invites && !invites.any((i) => i.id === this.invite.id)) {
        invites.unshiftObject(this.invite);
      }
      this.flashText = sanitize(I18n.t("user.invited.invite.invite_saved"));
      this.flashClass = "success";
      this.flashLink = !this.args.model.editing;
    } catch (error) {
      this.flashText = sanitize(extractError(error));
      this.flashClass = "error";
      this.flashLink = false;
    } finally {
      this.saving = false;
    }
  }

  get maxRedemptionsAllowedLimit() {
    if (this.currentUser.staff) {
      return this.siteSettings.invite_link_max_redemptions_limit;
    } else {
      return this.siteSettings.invite_link_max_redemptions_limit_users;
    }
  }

  get canInviteToGroup() {
    return (
      this.currentUser.staff || this.currentUser.groups.any((g) => g.owner)
    );
  }

  get canArriveAtTopic() {
    return this.currentUser.staff && !this.siteSettings.must_approve_users;
  }

  @action
  copied() {
    this.save({ sendEmail: false, copy: true });
  }

  @action
  async onFormSubmit(data) {
    await this.save(
      {
        emailOrDomain: data.restrictTo,
        groupIds: data.inviteToGroups,
        topicId: data.inviteToTopic,
        max_redemptions_allowed: data.maxRedemptions,
        expires_at: moment().add(data.expireAfterDays, "days").format(FORMAT),
        custom_message: data.customMessage,
      },
      {}
    );
  }

  @action
  registerSubmitButton(submitButton) {
    this.submitButton = submitButton;
  }

  @action
  saveInvite() {
    this.submitButton.click();
  }

  @action
  searchContact() {
    getNativeContact(this.capabilities, ["email"], false).then((result) => {
      this.set("buffered.email", result[0].email[0]);
    });
  }

  @action
  onChangeTopic(fieldSet, topicId, topic) {
    this.topics = [topic];
    fieldSet(topicId);
  }

  @action
  showAdvancedMode() {
    this.displayAdvancedOptions = true;
  }

  get simpleMode() {
    return !this.invite?.id && !this.displayAdvancedOptions;
  }

  get isNewInvite() {
    // use .get to track the id
    return !this.invite.get("id");
  }

  get isExistingInvite() {
    return !this.isNewInvite;
  }

  @action
  async createLink() {
    // TODO: do we need topicId here when the modal is opended via share topic?
    await this.save(
      {
        max_redemptions_allowed: this.maxRedemptionsAllowedLimit,
        expires_at: moment()
          .add(this.siteSettings.invite_expiry_days, "days")
          .format(FORMAT),
      },
      {}
    );
  }

  @action
  cancel() {
    this.args.closeModal();
  }

  <template>
    <DModal
      class="create-invite-modal"
      @title={{i18n
        (if
          @model.editing
          "user.invited.invite.edit_title"
          "user.invited.invite.new_title"
        )
      }}
      @closeModal={{@closeModal}}
      @hideFooter={{and this.simpleMode this.isExistingInvite}}
    >
      <:belowHeader>
        {{#if (and this.flashText (not this.simpleMode))}}
          <div
            id="modal-alert"
            role="alert"
            class="alert alert-{{this.flashClass}}"
          >
            {{#if this.flashLink}}
              <div class="input-group invite-link">
                <label for="invite-link">{{htmlSafe this.flashText}}
                  {{i18n "user.invited.invite.instructions"}}</label>
                <div class="link-share-container">
                  <input
                    name="invite-link"
                    class="invite-link"
                    value={{this.invite.link}}
                    readonly={{true}}
                  />
                  <CopyButton @selector="input.invite-link" />
                </div>
              </div>
            {{else}}
              {{htmlSafe this.flashText}}
            {{/if}}
          </div>
        {{else if @model.editing}}
          <div id="modal-alert" role="alert" class="alert alert-info">
            <div class="input-group invite-link">
              <label for="invite-link">{{htmlSafe this.flashText}}
                {{i18n "user.invited.invite.copy_link_and_share_it"}}</label>
              <div class="link-share-container">
                <input
                  name="invite-link"
                  class="invite-link"
                  value={{this.invite.link}}
                  readonly={{true}}
                />
                <CopyButton
                  @selector="input.invite-link"
                  @translatedLabel={{i18n "user.invited.invite.copy_link"}}
                  @translatedLabelAfterCopy={{i18n
                    "user.invited.invite.link_copied"
                  }}
                />
              </div>
            </div>
          </div>
        {{/if}}
      </:belowHeader>
      <:body>
        {{#if this.simpleMode}}
          {{#if this.isExistingInvite}}
            <p>
              {{i18n "user.invited.invite.copy_link_and_share_it"}}
            </p>
            <div class="link-share-container">
              <input
                name="invite-link"
                class="invite-link"
                value={{this.invite.link}}
                readonly={{true}}
              />
              <CopyButton
                @selector="input.invite-link"
                @translatedLabel={{i18n "user.invited.invite.copy_link"}}
                @translatedLabelAfterCopy={{i18n
                  "user.invited.invite.link_copied"
                }}
              />
            </div>
          {{else}}
            <p>
              {{i18n "user.invited.invite.create_link_to_invite"}}
            </p>
          {{/if}}
          <p>
            {{this.linkValidityMessageFormat}}
            <a {{on "click" this.showAdvancedMode}}>{{i18n
                "user.invited.invite.edit_link_options"
              }}</a>
          </p>
        {{else}}
          <Form
            @data={{this.data}}
            @onSubmit={{this.onFormSubmit}}
            as |form transientData|
          >
            <form.Field
              @name="restrictTo"
              @title={{i18n "user.invited.invite.restrict"}}
              @format="large"
              as |field|
            >
              <field.Input
                placeholder={{i18n
                  "user.invited.invite.email_or_domain_placeholder"
                }}
              />
            </form.Field>

            {{#unless (emailValid transientData.restrictTo)}}
              <form.Field
                @name="maxRedemptions"
                @title={{i18n "user.invited.invite.max_redemptions_allowed"}}
                @type="number"
                @format="small"
                @validation="required"
                as |field|
              >
                <field.Input
                  type="number"
                  min="1"
                  max={{this.maxRedemptionsAllowedLimit}}
                />
              </form.Field>
            {{/unless}}

            <form.Field
              @name="expireAfterDays"
              @title={{i18n "user.invited.invite.expires_at"}}
              @format="large"
              @validation="required"
              as |field|
            >
              <field.Select as |select|>
                {{#each this.expireAfterOptions as |option|}}
                  <select.Option
                    @value={{option.value}}
                  >{{option.text}}</select.Option>
                {{/each}}
              </field.Select>
            </form.Field>

            {{#if this.canArriveAtTopic}}
              <form.Field
                @name="inviteToTopic"
                @title={{i18n "user.invited.invite.invite_to_topic"}}
                @format="large"
                as |field|
              >
                <field.Custom>
                  <TopicChooser
                    @value={{field.value}}
                    @content={{this.topics}}
                    @onChange={{fn this.onChangeTopic field.set}}
                    @options={{hash additionalFilters="status:public"}}
                  />
                </field.Custom>
              </form.Field>
            {{else if this.topicTitle}}
              <form.Field
                @name="inviteToTopicTitle"
                @title={{i18n "user.invited.invite.invite_to_topic"}}
                @format="large"
                as |field|
              >
                <field.Input disabled={{true}} />
              </form.Field>
            {{/if}}

            {{#if this.canInviteToGroup}}
              <form.Field
                @name="inviteToGroups"
                @title={{i18n "user.invited.invite.add_to_groups"}}
                @format="large"
                @description={{i18n
                  "user.invited.invite.cannot_invite_predefined_groups"
                  (hash path=(getURL "/g"))
                }}
                as |field|
              >
                <field.Custom>
                  <GroupChooser
                    @content={{this.allGroups}}
                    @value={{field.value}}
                    @labelProperty="name"
                    @onChange={{field.set}}
                  />
                </field.Custom>
              </form.Field>
            {{/if}}

            {{#if (emailValid transientData.restrictTo)}}
              <form.Field
                @name="customMessage"
                @title={{i18n "user.invited.invite.custom_message"}}
                @format="large"
                as |field|
              >
                <field.Textarea
                  height={{100}}
                  placeholder={{i18n
                    "user.invited.invite.custom_message_placeholder"
                  }}
                />
              </form.Field>
            {{/if}}

            <form.Submit
              {{didInsert this.registerSubmitButton}}
              @label="save"
              class="hidden"
            />
          </Form>
        {{/if}}
      </:body>
      <:footer>
        {{#if this.simpleMode}}
          <DButton
            @label="user.invited.invite.create_link"
            @action={{this.createLink}}
            @disabled={{this.saving}}
            class="btn-primary save-invite"
          />
        {{else}}
          <DButton
            @label="user.invited.invite.save_invite"
            @action={{this.saveInvite}}
            @disabled={{this.saving}}
            class="btn-primary save-invite"
          />
        {{/if}}
        <DButton
          @label="user.invited.invite.cancel"
          @action={{this.cancel}}
          class="btn-transparent"
        />
      </:footer>
    </DModal>
  </template>
}

import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, notEq, or } from "truth-helpers";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import FutureDateInput from "discourse/components/future-date-input";
import { extractError } from "discourse/lib/ajax-error";
import { canNativeShare, nativeShare } from "discourse/lib/pwa-utils";
import { sanitize } from "discourse/lib/text";
import { emailValid, hostnameValid } from "discourse/lib/utilities";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import { FORMAT as DATE_INPUT_FORMAT } from "select-kit/components/future-date-input-selector";
import GroupChooser from "select-kit/components/group-chooser";
import TopicChooser from "select-kit/components/topic-chooser";

export default class CreateInvite extends Component {
  @service capabilities;
  @service currentUser;
  @service siteSettings;
  @service site;

  @tracked saving = false;
  @tracked displayAdvancedOptions = false;
  @tracked isEmailInvite = emailValid(this.data.restrictTo);

  @tracked flashText;
  @tracked flashClass = "info";

  @tracked topics = this.invite.topics ?? this.model.topics ?? [];
  @tracked allGroups;

  model = this.args.model;
  invite = this.model.invite ?? Invite.create();
  sendEmail = false;
  formApi;

  constructor() {
    super(...arguments);

    Group.findAll().then((groups) => {
      this.allGroups = groups.filter((group) => !group.automatic);
    });
  }

  get linkValidityMessageFormat() {
    return I18n.messageFormat("user.invited.invite.link_validity_MF", {
      user_count: this.defaultRedemptionsAllowed,
      duration_days: this.siteSettings.invite_expiry_days,
    });
  }

  get expireAfterOptions() {
    let list = [1, 7, 30, 90];

    if (!list.includes(this.siteSettings.invite_expiry_days)) {
      list.push(this.siteSettings.invite_expiry_days);
    }

    list = list
      .sort((a, b) => a - b)
      .map((days) => {
        return {
          value: days,
          text: I18n.t("dates.medium.x_days", { count: days }),
        };
      });

    list.push({
      value: 999999,
      text: I18n.t("time_shortcut.never"),
    });

    return list;
  }

  @cached
  get data() {
    const data = {
      restrictTo: this.invite.emailOrDomain ?? "",
      maxRedemptions:
        this.invite.max_redemptions_allowed ?? this.defaultRedemptionsAllowed,
      inviteToTopic: this.invite.topicId,
      inviteToGroups: this.model.groupIds ?? this.invite.groupIds ?? [],
      customMessage: this.invite.custom_message ?? "",
    };

    if (this.inviteCreated) {
      data.expiresAt = this.invite.expires_at;
    } else {
      data.expiresAfterDays = this.siteSettings.invite_expiry_days;
    }

    return data;
  }

  async save(data) {
    let isLink = true;

    if (data.emailOrDomain) {
      if (this.isEmailInvite) {
        isLink = false;
        data.email = data.emailOrDomain;
      } else if (hostnameValid(data.emailOrDomain)) {
        data.domain = data.emailOrDomain;
      }
      delete data.emailOrDomain;
    }

    if (isLink) {
      if (this.invite.email) {
        data.email = data.custom_message = "";
      }
    } else {
      if (data.max_redemptions_allowed > 1) {
        data.max_redemptions_allowed = 1;
      }

      if (this.sendEmail) {
        data.send_email = true;
        if (data.topic_id) {
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
      if (invites && !invites.some((i) => i.id === this.invite.id)) {
        invites.unshiftObject(this.invite);
      }

      if (!this.simpleMode) {
        if (this.sendEmail) {
          this.flashText = sanitize(
            I18n.t("user.invited.invite.invite_saved_with_sending_email")
          );
        } else {
          this.flashText = sanitize(
            I18n.t("user.invited.invite.invite_saved_without_sending_email")
          );
        }
        this.flashClass = "success";
      }
    } catch (error) {
      this.flashText = sanitize(extractError(error));
      this.flashClass = "error";
    } finally {
      this.saving = false;
    }
  }

  get maxRedemptionsAllowedLimit() {
    if (this.currentUser.staff) {
      return this.siteSettings.invite_link_max_redemptions_limit;
    }

    return this.siteSettings.invite_link_max_redemptions_limit_users;
  }

  get defaultRedemptionsAllowed() {
    const max = this.maxRedemptionsAllowedLimit;
    const val = this.currentUser.staff ? 100 : 10;
    return Math.min(max, val);
  }

  get canInviteToGroup() {
    return (
      this.currentUser.staff ||
      this.currentUser.groups.some((g) => g.group_user?.owner)
    );
  }

  get canArriveAtTopic() {
    return this.currentUser.staff && !this.siteSettings.must_approve_users;
  }

  get simpleMode() {
    return !this.args.model.editing && !this.displayAdvancedOptions;
  }

  get inviteCreated() {
    // use .get to track the id
    return !!this.invite.get("id");
  }

  @action
  handleRestrictToChange(value, { set }) {
    set("restrictTo", value);
    this.isEmailInvite = emailValid(value);
  }

  @action
  async onFormSubmit(data) {
    const submitData = {
      emailOrDomain: data.restrictTo?.trim(),
      group_ids: data.inviteToGroups,
      topic_id: data.inviteToTopic,
      max_redemptions_allowed: data.maxRedemptions,
      custom_message: data.customMessage,
    };

    if (data.expiresAt) {
      submitData.expires_at = data.expiresAt;
    } else if (data.expiresAfterDays) {
      submitData.expires_at = moment()
        .add(data.expiresAfterDays, "days")
        .format(DATE_INPUT_FORMAT);
    }

    await this.save(submitData);
  }

  @action
  saveInvite() {
    this.sendEmail = false;
    this.formApi.submit();
  }

  @action
  saveInviteAndSendEmail() {
    this.sendEmail = true;
    this.formApi.submit();
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

  @action
  async createLink() {
    this.sendEmail = false;
    await this.save({
      max_redemptions_allowed: this.defaultRedemptionsAllowed,
      expires_at: moment()
        .add(this.siteSettings.invite_expiry_days, "days")
        .format(DATE_INPUT_FORMAT),
    });
  }

  @action
  cancel() {
    this.args.closeModal();
  }

  @action
  registerApi(api) {
    this.formApi = api;
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
      @hideFooter={{and this.simpleMode this.inviteCreated}}
      @inline={{@inline}}
    >
      <:belowHeader>
        {{#if (or this.flashText @model.editing)}}
          <InviteModalAlert
            @invite={{this.invite}}
            @alertClass={{this.flashClass}}
            @showInviteLink={{and
              this.inviteCreated
              (notEq this.flashClass "error")
            }}
          >
            {{#if this.flashText}}
              {{htmlSafe this.flashText}}
            {{else}}
              {{i18n "user.invited.invite.copy_link_and_share_it"}}
            {{/if}}
          </InviteModalAlert>
        {{/if}}
      </:belowHeader>
      <:body>
        {{#if this.simpleMode}}
          {{#if this.inviteCreated}}
            {{#unless this.site.mobileView}}
              <p>
                {{i18n "user.invited.invite.copy_link_and_share_it"}}
              </p>
            {{/unless}}
            <div class="link-share-container">
              <ShareOrCopyInviteLink @invite={{this.invite}} />
            </div>
          {{else}}
            <p>
              {{i18n "user.invited.invite.create_link_to_invite"}}
            </p>
          {{/if}}
          <p class="link-limits-info">
            {{this.linkValidityMessageFormat}}
            <a
              class="edit-link-options"
              role="button"
              {{on "click" this.showAdvancedMode}}
            >{{i18n "user.invited.invite.edit_link_options"}}</a>
          </p>
        {{else}}
          <Form
            @data={{this.data}}
            @onSubmit={{this.onFormSubmit}}
            @onRegisterApi={{this.registerApi}}
            as |form|
          >
            <form.Field
              @name="restrictTo"
              @title={{i18n "user.invited.invite.restrict"}}
              @format="large"
              @onSet={{this.handleRestrictToChange}}
              as |field|
            >
              <field.Input
                placeholder={{i18n
                  "user.invited.invite.email_or_domain_placeholder"
                }}
              />
            </form.Field>

            {{#unless this.isEmailInvite}}
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

            {{#if this.inviteCreated}}
              <form.Field
                @name="expiresAt"
                @title={{i18n "user.invited.invite.expires_at"}}
                @format="large"
                @validation="required"
                as |field|
              >
                <field.Custom>
                  <FutureDateInput
                    @clearable={{true}}
                    @input={{field.value}}
                    @noRelativeOptions={{true}}
                    @onChangeInput={{field.set}}
                  />
                </field.Custom>
              </form.Field>
            {{else}}
              <form.Field
                @name="expiresAfterDays"
                @title={{i18n "user.invited.invite.expires_after"}}
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
            {{/if}}

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
            {{/if}}

            {{#if this.canInviteToGroup}}
              <form.Field
                @name="inviteToGroups"
                @title={{i18n "user.invited.invite.add_to_groups"}}
                @format="large"
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

            {{#if this.isEmailInvite}}
              <form.Field
                @name="customMessage"
                @title={{i18n "user.invited.invite.custom_message"}}
                @format="full"
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
            @label={{if
              this.inviteCreated
              "user.invited.invite.update_invite"
              "user.invited.invite.create_link"
            }}
            @action={{this.saveInvite}}
            @disabled={{this.saving}}
            class="btn-primary save-invite"
          />
          {{#if this.isEmailInvite}}
            <DButton
              @label={{if
                this.inviteCreated
                "user.invited.invite.update_invite_and_send_email"
                "user.invited.invite.create_link_and_send_email"
              }}
              @action={{this.saveInviteAndSendEmail}}
              @disabled={{this.saving}}
              class="btn-primary save-invite-and-send-email"
            />
          {{/if}}
        {{/if}}
        <DButton
          @label="user.invited.invite.cancel"
          @action={{this.cancel}}
          class="btn-transparent cancel-button"
        />
      </:footer>
    </DModal>
  </template>
}

const InviteModalAlert = <template>
  <div id="modal-alert" role="alert" class="alert alert-{{@alertClass}}">
    <div class="input-group invite-link">
      <label for="invite-link">
        {{yield}}
      </label>
      {{#if @showInviteLink}}
        <div class="link-share-container">
          <ShareOrCopyInviteLink @invite={{@invite}} />
        </div>
      {{/if}}
    </div>
  </div>
</template>;

class ShareOrCopyInviteLink extends Component {
  @service capabilities;

  @action
  async nativeShare() {
    await nativeShare(this.capabilities, { url: this.args.invite.link });
  }

  <template>
    <input
      name="invite-link"
      type="text"
      class="invite-link"
      value={{@invite.link}}
      readonly={{true}}
    />
    {{#if (canNativeShare this.capabilities)}}
      <DButton
        class="btn-primary"
        @icon="share"
        @translatedLabel={{i18n "user.invited.invite.share_link"}}
        @action={{this.nativeShare}}
      />
    {{else}}
      <CopyButton
        @selector="input.invite-link"
        @translatedLabel={{i18n "user.invited.invite.copy_link"}}
        @translatedLabelAfterCopy={{i18n "user.invited.invite.link_copied"}}
      />
    {{/if}}
  </template>
}

import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { extractError } from "discourse/lib/ajax-error";
import { INVITE_DESCRIPTION_MAX_LENGTH } from "discourse/lib/constants";
import { shortDate } from "discourse/lib/formatter";
import { canNativeShare, nativeShare } from "discourse/lib/pwa-utils";
import { sanitize } from "discourse/lib/text";
import {
  clipboardCopyAsync,
  emailValid,
  hostnameValid,
} from "discourse/lib/utilities";
import Invite from "discourse/models/invite";
import { FORMAT as DATE_INPUT_FORMAT } from "discourse/select-kit/components/future-date-input-selector";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DCopyButton from "discourse/ui-kit/d-copy-button";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const FORM = "form";
const SUMMARY = "summary";
const EMAIL_SENT = "email-sent";

export default class CreateInviteWithRoles extends Component {
  @service appEvents;
  @service currentUser;
  @service site;
  @service siteSettings;

  @tracked saving = false;
  @tracked showAdvanced = false;
  @tracked screen = FORM;
  @tracked role;
  @tracked delivery;
  @tracked submitForcedDisabled = false;
  @tracked flashText;
  @tracked flashClass = "info";

  @tracked topics = this.invite.topics ?? this.model.topics ?? [];
  model = this.args.model;
  invite = this.model.invite ?? Invite.create();

  allGroups = this.site.groups.filter((g) => !g.automatic);
  cameFromSummary = false;
  formApi;

  constructor() {
    super(...arguments);

    if (this.inviteCreated) {
      this.role = this.invite.is_admin ? "admin" : "member";
      this.delivery = this.invite.email ? "email" : "link";
    } else {
      this.role =
        this.model.defaultRole === "admin" && this.canInviteAdmins
          ? "admin"
          : "member";
      this.delivery = "link";
    }
  }

  get canInviteAdmins() {
    return !!this.currentUser?.can_create_admin_invite;
  }

  get roleItems() {
    return [
      {
        value: "member",
        label: i18n("user.invited.invite_roles.member_tab"),
        icon: "user",
        disabled: this.inviteCreated && this.isAdminInvite,
      },
      {
        value: "admin",
        label: i18n("user.invited.invite_roles.admin_tab"),
        icon: "shield-halved",
        disabled: this.inviteCreated && !this.isAdminInvite,
      },
    ];
  }

  get isAdminInvite() {
    return this.role === "admin";
  }

  get isEmailDelivery() {
    return this.isAdminInvite || this.delivery === "email";
  }

  get inviteCreated() {
    return !!this.invite.get("id");
  }

  get title() {
    if (this.screen === SUMMARY) {
      return this.invite.email
        ? i18n("user.invited.invite_roles.sent_title")
        : i18n("user.invited.invite_roles.created_title");
    }

    if (this.screen === EMAIL_SENT) {
      return i18n("user.invited.invite_roles.sent_title");
    }

    if (this.inviteCreated || this.model.editing) {
      return i18n("user.invited.invite_roles.edit_title");
    }

    return this.isAdminInvite
      ? i18n("user.invited.invite_roles.admin_title")
      : i18n("user.invited.invite_roles.member_title");
  }

  get roleDescription() {
    return this.isAdminInvite
      ? i18n("user.invited.invite_roles.admin_description")
      : i18n("user.invited.invite_roles.member_description");
  }

  get descriptionValidation() {
    return `length:0,${INVITE_DESCRIPTION_MAX_LENGTH}`;
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
          text: i18n("dates.medium.x_days", { count: days }),
        };
      });

    list.push({
      value: 999999,
      text: i18n("time_shortcut.never"),
    });

    return list;
  }

  @cached
  get adminFormData() {
    const data = {
      email: this.invite.email ?? "",
      description: this.invite.description ?? "",
      customMessage: this.invite.custom_message ?? "",
    };

    if (this.inviteCreated) {
      data.expiresAt = this.invite.expires_at;
    } else {
      data.expiresAfterDays = this.siteSettings.invite_expiry_days;
    }

    return data;
  }

  @cached
  get memberFormData() {
    const data = {
      email: this.invite.email ?? "",
      domain: this.invite.domain ?? "",
      description: this.invite.description ?? "",
      maxRedemptions:
        this.invite.max_redemptions_allowed ?? this.defaultRedemptionsAllowed,
      inviteToTopic: this.model.topicId ?? this.invite.topicId,
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

  get summaryRows() {
    const rows = [
      {
        label: i18n("user.invited.invite_roles.summary.role"),
        value: this.invite.is_admin
          ? i18n("user.invited.invite_roles.summary.role_admin")
          : i18n("user.invited.invite_roles.summary.role_member"),
      },
      {
        label: i18n("user.invited.invite_roles.summary.method"),
        value: this.invite.email
          ? i18n("user.invited.invite_roles.summary.method_email")
          : i18n("user.invited.invite_roles.summary.method_link"),
      },
    ];

    if (this.invite.email || this.invite.domain) {
      rows.push({
        label: i18n("user.invited.invite_roles.summary.restriction"),
        value: this.invite.email || this.invite.domain,
      });
    }

    if (!this.invite.email) {
      rows.push({
        label: i18n("user.invited.invite_roles.summary.uses"),
        value: this.invite.max_redemptions_allowed,
      });
    }

    if (this.invite.expires_at) {
      rows.push({
        label: i18n("user.invited.invite_roles.summary.expires"),
        value: shortDate(this.invite.expires_at),
      });
    }

    if (this.invite.topic) {
      rows.push({
        label: i18n("user.invited.invite_roles.summary.topic"),
        value: this.invite.topic.title,
      });
    }

    if (this.invite.groups?.length) {
      rows.push({
        label: i18n("user.invited.invite_roles.summary.groups"),
        value: this.invite.groups.map((g) => g.name).join(", "),
      });
    }

    return rows;
  }

  expiresAtFrom(data) {
    if (data.expiresAt) {
      return data.expiresAt;
    }

    return moment()
      .add(data.expiresAfterDays, "days")
      .format(DATE_INPUT_FORMAT);
  }

  async save(data, nextScreen) {
    this.saving = true;
    this.flashText = null;

    try {
      await this.invite.save(data);

      const invites = this.model?.invites;
      if (invites && !invites.some((i) => i.id === this.invite.id)) {
        invites.unshift(this.invite);
      }

      this.appEvents.trigger("create-invite:saved", this.invite);
      this.showAdvanced = false;
      this.screen = nextScreen;
    } catch (error) {
      this.flashText = sanitize(extractError(error));
      this.flashClass = "error";
    } finally {
      this.saving = false;
    }
  }

  get submitDisabled() {
    return this.saving || this.submitForcedDisabled;
  }

  get isLinkCreation() {
    return !this.inviteCreated && !this.isEmailDelivery;
  }

  @action
  onRoleChange(value) {
    if (this.inviteCreated) {
      return;
    }
    this.role = value;
    // anything rendered into the admin-mode outlet is torn down on role
    // change, so its submit lock must not outlive it
    this.submitForcedDisabled = false;
  }

  @action
  setDelivery(value) {
    this.delivery = value;
  }

  get emailFieldLabel() {
    return this.isAdminInvite
      ? i18n("user.invited.invite_roles.admin_email_label")
      : i18n("user.invited.invite_roles.member_email_label");
  }

  @action
  validateEmail(name, value, { addError }) {
    if (value && !emailValid(value.trim())) {
      addError(name, {
        title: this.emailFieldLabel,
        message: i18n("user.email.invalid"),
      });
    }
  }

  @action
  validateDomain(name, value, { addError }) {
    if (value && !hostnameValid(value.trim())) {
      addError(name, {
        title: i18n("user.invited.invite_roles.restrict_domain"),
        message: i18n("user.invited.invite_roles.domain_invalid"),
      });
    }
  }

  @action
  async onAdminFormSubmit(data) {
    const wasCreated = this.inviteCreated;
    const submitData = {
      email: data.email?.trim(),
      description: data.description,
      custom_message: data.customMessage,
      expires_at: this.expiresAtFrom(data),
    };

    if (!wasCreated) {
      submitData.is_admin = true;
    }

    await this.save(submitData, SUMMARY);
  }

  @action
  async onMemberFormSubmit(data) {
    const submitData = {
      description: data.description,
      group_ids: data.inviteToGroups,
      topic_id: data.inviteToTopic,
      expires_at: this.expiresAtFrom(data),
    };

    let nextScreen = SUMMARY;
    if (this.delivery === "email") {
      submitData.email = data.email?.trim();
      submitData.custom_message = data.customMessage;
      if (!this.inviteCreated) {
        nextScreen = EMAIL_SENT;
      }
    } else {
      submitData.domain = data.domain?.trim();
      submitData.max_redemptions_allowed = data.maxRedemptions;
      submitData.skip_email = true;
    }

    await this.save(submitData, nextScreen);
  }

  @action
  async submitForm() {
    if (this.isLinkCreation) {
      // save and copy in one user gesture so the browser allows the
      // clipboard write after the network round-trip
      try {
        await clipboardCopyAsync(async () => {
          await this.formApi.submit();
          if (!this.inviteCreated) {
            throw new Error("invite was not created");
          }
          return new Blob([this.invite.link], { type: "text/plain" });
        });
      } catch {
        // saving errors are surfaced via the form flash; clipboard errors
        // are recoverable from the summary screen's copy button
      }
    } else {
      await this.formApi.submit();
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  setSubmitDisabled(value) {
    this.submitForcedDisabled = !!value;
  }

  @action
  toggleAdvanced() {
    this.showAdvanced = !this.showAdvanced;
  }

  @action
  onChangeTopic(fieldSet, topicId, topic) {
    this.topics = [topic];
    fieldSet(topicId);
  }

  @action
  editInvite() {
    this.cameFromSummary = true;
    this.screen = FORM;
  }

  @action
  cancel() {
    if (this.cameFromSummary && this.inviteCreated) {
      this.cameFromSummary = false;
      this.screen = SUMMARY;
    } else {
      this.args.closeModal();
    }
  }

  <template>
    <DModal
      class="create-invite-with-roles-modal"
      @title={{this.title}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
    >
      <:belowHeader>
        {{#if this.flashText}}
          <div id="modal-alert" role="alert" class="alert alert-error">
            {{trustHTML this.flashText}}
          </div>
        {{/if}}
      </:belowHeader>
      <:body>
        {{#if (eq this.screen "form")}}
          <div class="create-invite-with-roles-modal__role">
            {{#if this.canInviteAdmins}}
              <fieldset class="create-invite-with-roles-modal__role-toggle">
                <legend class="sr-only">
                  {{i18n "user.invited.invite_roles.role_label"}}
                </legend>
                {{#each this.roleItems as |item|}}
                  <label
                    class="create-invite-with-roles-modal__role-option
                      {{if (eq this.role item.value) '--active'}}
                      {{if item.disabled '--disabled'}}"
                  >
                    <input
                      type="radio"
                      name="invite-role"
                      value={{item.value}}
                      checked={{eq this.role item.value}}
                      disabled={{item.disabled}}
                      {{on "change" (fn this.onRoleChange item.value)}}
                    />
                    {{dIcon item.icon}}
                    {{item.label}}
                  </label>
                {{/each}}
              </fieldset>
            {{/if}}
            <p class="create-invite-with-roles-modal__role-description">
              {{this.roleDescription}}
              {{#if this.inviteCreated}}
                <span class="create-invite-with-roles-modal__role-locked">
                  {{i18n "user.invited.invite_roles.role_locked"}}
                </span>
              {{/if}}
            </p>
          </div>

          {{#if this.isAdminInvite}}
            <PluginOutlet
              @name="create-invite-admin-mode"
              @connectorTagName="div"
              @outletArgs={{lazyHash
                invite=this.invite
                setSubmitDisabled=this.setSubmitDisabled
              }}
            />

            <Form
              @data={{this.adminFormData}}
              @onSubmit={{this.onAdminFormSubmit}}
              @onRegisterApi={{this.registerApi}}
              class="create-invite-with-roles-modal__admin-form"
              as |form|
            >
              <form.Field
                @name="email"
                @type="input-email"
                @title={{this.emailFieldLabel}}
                @validation="required"
                @validate={{this.validateEmail}}
                @format="full"
                as |field|
              >
                <field.Control
                  autofocus="autofocus"
                  placeholder={{i18n
                    "user.invited.invite_roles.email_placeholder"
                  }}
                />
              </form.Field>

              {{#if this.showAdvanced}}
                <form.Field
                  @name="description"
                  @type="input"
                  @title={{i18n "user.invited.invite.description"}}
                  @description={{i18n "user.invited.invite.description_help"}}
                  @format="full"
                  @validation={{this.descriptionValidation}}
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @name="customMessage"
                  @type="textarea"
                  @title={{i18n "user.invited.invite.custom_message"}}
                  @description={{i18n
                    "user.invited.invite.custom_message_help"
                  }}
                  @format="full"
                  as |field|
                >
                  <field.Control
                    height={{100}}
                    placeholder={{i18n
                      "user.invited.invite.custom_message_placeholder"
                    }}
                  />
                </form.Field>

                <ExpiryField
                  @form={{form}}
                  @created={{this.inviteCreated}}
                  @options={{this.expireAfterOptions}}
                />
              {{/if}}
            </Form>
          {{else}}
            <Form
              @data={{this.memberFormData}}
              @onSubmit={{this.onMemberFormSubmit}}
              @onRegisterApi={{this.registerApi}}
              class="create-invite-with-roles-modal__member-form"
              as |form|
            >
              {{#unless this.inviteCreated}}
                <fieldset class="create-invite-with-roles-modal__delivery">
                  <legend
                    class="create-invite-with-roles-modal__delivery-label"
                  >{{i18n "user.invited.invite_roles.invite_by"}}</legend>
                  {{#each
                    (array
                      (hash
                        value="link"
                        label=(i18n "user.invited.invite_roles.invite_by_link")
                      )
                      (hash
                        value="email"
                        label=(i18n "user.invited.invite_roles.invite_by_email")
                      )
                    )
                    as |item|
                  }}
                    <label
                      class="create-invite-with-roles-modal__delivery-option"
                    >
                      <input
                        type="radio"
                        name="invite-delivery"
                        value={{item.value}}
                        checked={{eq this.delivery item.value}}
                        {{on "change" (fn this.setDelivery item.value)}}
                      />
                      {{item.label}}
                    </label>
                  {{/each}}
                </fieldset>
              {{/unless}}

              {{#if (eq this.delivery "email")}}
                <form.Field
                  @name="email"
                  @type="input-email"
                  @title={{this.emailFieldLabel}}
                  @description={{i18n
                    "user.invited.invite_roles.member_email_help"
                  }}
                  @validation="required"
                  @validate={{this.validateEmail}}
                  @format="full"
                  @disabled={{this.inviteCreated}}
                  as |field|
                >
                  <field.Control
                    placeholder={{i18n
                      "user.invited.invite_roles.email_placeholder"
                    }}
                  />
                </form.Field>
              {{else}}
                <form.Field
                  @name="domain"
                  @type="input"
                  @title={{i18n "user.invited.invite_roles.restrict_domain"}}
                  @description={{i18n
                    "user.invited.invite_roles.restrict_domain_help"
                  }}
                  @validate={{this.validateDomain}}
                  @format="full"
                  as |field|
                >
                  <field.Control
                    autofocus="autofocus"
                    placeholder={{i18n
                      "user.invited.invite_roles.domain_placeholder"
                    }}
                  />
                </form.Field>
              {{/if}}

              {{#if this.showAdvanced}}
                {{#if (eq this.delivery "email")}}
                  <form.Field
                    @name="customMessage"
                    @type="textarea"
                    @title={{i18n "user.invited.invite.custom_message"}}
                    @description={{i18n
                      "user.invited.invite.custom_message_help"
                    }}
                    @format="full"
                    as |field|
                  >
                    <field.Control
                      height={{100}}
                      placeholder={{i18n
                        "user.invited.invite.custom_message_placeholder"
                      }}
                    />
                  </form.Field>
                {{else}}
                  <form.Field
                    @name="maxRedemptions"
                    @title={{i18n
                      "user.invited.invite.max_redemptions_allowed"
                    }}
                    @type="input-number"
                    @format="small"
                    @validation="required"
                    as |field|
                  >
                    <field.Control
                      min="1"
                      max={{this.maxRedemptionsAllowedLimit}}
                    />
                  </form.Field>
                {{/if}}

                <form.Field
                  @name="description"
                  @type="input"
                  @title={{i18n "user.invited.invite.description"}}
                  @description={{i18n "user.invited.invite.description_help"}}
                  @format="full"
                  @validation={{this.descriptionValidation}}
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <ExpiryField
                  @form={{form}}
                  @created={{this.inviteCreated}}
                  @options={{this.expireAfterOptions}}
                />

                {{#if this.canArriveAtTopic}}
                  <form.Field
                    @name="inviteToTopic"
                    @type="custom"
                    @title={{i18n "user.invited.invite.invite_to_topic"}}
                    @description={{i18n
                      "user.invited.invite_roles.arrive_at_topic_help"
                    }}
                    @format="full"
                    as |field|
                  >
                    <field.Control>
                      <TopicChooser
                        @value={{field.value}}
                        @content={{this.topics}}
                        @onChange={{fn this.onChangeTopic field.set}}
                        @options={{hash additionalFilters="status:public"}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                {{#if this.canInviteToGroup}}
                  <form.Field
                    @name="inviteToGroups"
                    @type="custom"
                    @title={{i18n "user.invited.invite.add_to_groups"}}
                    @format="full"
                    as |field|
                  >
                    <field.Control>
                      <GroupChooser
                        @content={{this.allGroups}}
                        @value={{field.value}}
                        @labelProperty="name"
                        @onChange={{field.set}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}
              {{/if}}
            </Form>
          {{/if}}
        {{else if (eq this.screen "summary")}}
          <div class="create-invite-with-roles-modal__summary">
            {{#if this.invite.email}}
              <p class="create-invite-with-roles-modal__sent-to">
                {{i18n
                  "user.invited.invite_roles.summary.sent_to"
                  email=this.invite.email
                }}
              </p>
            {{/if}}

            <div class="create-invite-with-roles-modal__link-share">
              <ShareOrCopyInviteLink @invite={{this.invite}} />
            </div>

            <dl class="create-invite-with-roles-modal__summary-rows">
              {{#each this.summaryRows as |row|}}
                <div class="create-invite-with-roles-modal__summary-row">
                  <dt>{{row.label}}</dt>
                  <dd>{{row.value}}</dd>
                </div>
              {{/each}}
            </dl>
          </div>
        {{else}}
          <div class="create-invite-with-roles-modal__email-sent">
            <p>
              {{i18n
                "user.invited.invite_roles.email_sent.body"
                email=this.invite.email
              }}
            </p>
          </div>
        {{/if}}
      </:body>
      <:footer>
        {{#if (eq this.screen "form")}}
          <DButton
            @icon={{if
              this.inviteCreated
              "check"
              (if this.isEmailDelivery "paper-plane" "copy")
            }}
            @translatedLabel={{if
              this.inviteCreated
              (i18n "user.invited.invite_roles.update")
              (if
                this.isEmailDelivery
                (i18n "user.invited.invite_roles.create_and_send")
                (i18n "user.invited.invite_roles.create_and_copy")
              )
            }}
            @action={{this.submitForm}}
            @disabled={{this.submitDisabled}}
            class="btn-primary save-invite"
          />
          <DButton
            @label="user.invited.invite.cancel"
            @action={{this.cancel}}
            class="btn-transparent cancel-button"
          />
          <DButton
            @icon="gear"
            @translatedTitle={{if
              this.showAdvanced
              (i18n "user.invited.invite_roles.fewer_options")
              (i18n "user.invited.invite_roles.more_options")
            }}
            @action={{this.toggleAdvanced}}
            class="btn-default toggle-advanced
              {{if this.showAdvanced '--active'}}"
          />
        {{else if (eq this.screen "summary")}}
          <DButton
            @translatedLabel={{i18n "user.invited.invite_roles.summary.edit"}}
            @action={{this.editInvite}}
            class="btn-default edit-invite"
          />
          <LinkTo
            @route="userInvited.show"
            @models={{array this.currentUser.username_lower "pending"}}
            class="btn btn-transparent view-invites"
          >
            {{i18n "user.invited.invite_roles.summary.view_invites"}}
          </LinkTo>
        {{else}}
          <LinkTo
            @route="userInvited.show"
            @models={{array this.currentUser.username_lower "pending"}}
            class="btn btn-transparent view-invites"
          >
            {{i18n "user.invited.invite_roles.summary.view_invites"}}
          </LinkTo>
        {{/if}}
      </:footer>
    </DModal>
  </template>
}

const ExpiryField = <template>
  {{#if @created}}
    <@form.Field
      @name="expiresAt"
      @type="custom"
      @title={{i18n "user.invited.invite.expires_at"}}
      @format="full"
      @validation="required"
      as |field|
    >
      <field.Control>
        <DFutureDateInput
          @clearable={{true}}
          @input={{field.value}}
          @noRelativeOptions={{true}}
          @onChangeInput={{field.set}}
        />
      </field.Control>
    </@form.Field>
  {{else}}
    <@form.Field
      @name="expiresAfterDays"
      @type="select"
      @title={{i18n "user.invited.invite.expires_after"}}
      @format="full"
      @validation="required"
      as |field|
    >
      <field.Control as |select|>
        {{#each @options as |option|}}
          <select.Option @value={{option.value}}>{{option.text}}</select.Option>
        {{/each}}
      </field.Control>
    </@form.Field>
  {{/if}}
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
      <DCopyButton
        @selector="input.invite-link"
        @translatedLabel={{i18n "user.invited.invite.copy_link"}}
        @translatedLabelAfterCopy={{i18n "user.invited.invite.link_copied"}}
      />
    {{/if}}
  </template>
}

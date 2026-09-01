import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdvancedModeToggle from "discourse/components/advanced-mode-toggle";
import DSegmentedControl from "discourse/components/d-segmented-control";
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
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
  @tracked staffRole = "admin";
  @tracked delivery = "link";
  @tracked submitForcedDisabled = false;
  @tracked flashText;
  @tracked flashClass = "info";
  @tracked linkAutoCopied = false;

  @tracked topics = this.invite.topics ?? this.model.topics ?? [];
  model = this.args.model;
  invite = this.model.invite ?? Invite.create();

  allGroups = this.site.groups.filter((g) => !g.automatic);
  cameFromSummary = false;
  initialStaffRole;
  formApi;

  constructor() {
    super(...arguments);

    if (this.inviteCreated) {
      const isStaff = this.invite.grants_admin || this.invite.grants_moderator;
      this.role = isStaff ? "admin" : "member";
      this.staffRole = this.invite.grants_moderator ? "moderator" : "admin";
      this.delivery = this.invite.email ? "email" : "link";
    } else {
      this.role =
        this.model.defaultRole === "admin" && this.canInviteAdmins
          ? "admin"
          : "member";
      this.delivery = "link";
    }

    this.initialStaffRole = this.staffRole;
  }

  get allowEmailInvites() {
    return this.siteSettings.allow_email_invites;
  }

  get canInviteAdmins() {
    return !!this.currentUser?.can_create_admin_invite;
  }

  get canChooseRole() {
    return this.canInviteAdmins && !this.inviteCreated;
  }

  get roleItems() {
    return [
      {
        value: "member",
        label: i18n("user.invited.invite_roles.member_tab"),
        icon: "user",
      },
      {
        value: "admin",
        label: i18n("user.invited.invite_roles.admin_tab"),
        icon: "shield-halved",
      },
    ];
  }

  get isAdminInvite() {
    return this.role === "admin";
  }

  get isEmailDelivery() {
    return this.delivery === "email";
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

  get isModeratorInvite() {
    return this.isAdminInvite && this.staffRole === "moderator";
  }

  get staffRoleLabel() {
    return i18n("user.invited.invite_roles.staff_role_label");
  }

  get staffRoleItems() {
    return [
      {
        value: "admin",
        label: i18n("user.invited.invite_roles.staff_role_admin"),
      },
      {
        value: "moderator",
        label: i18n("user.invited.invite_roles.staff_role_moderator"),
      },
    ];
  }

  get staffRoleDescription() {
    return this.isModeratorInvite
      ? i18n("user.invited.invite_roles.moderator_description")
      : i18n("user.invited.invite_roles.admin_description");
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
      this.currentUser.visibleGroups.some((g) => g.group_user?.owner)
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
      domain: this.invite.domain ?? "",
      description: this.invite.description ?? "",
      customMessage: this.invite.custom_message ?? "",
      // seeded from the untracked copy: reading the tracked property here would
      // give `<Form>` a new @data identity on every change, tearing the form down
      staffRole: this.initialStaffRole,
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

  get summaryRoleValue() {
    if (this.invite.grants_admin) {
      return i18n("user.invited.invite_roles.summary.role_admin");
    }

    if (this.invite.grants_moderator) {
      return i18n("user.invited.invite_roles.summary.role_moderator");
    }

    return i18n("user.invited.invite_roles.summary.role_member");
  }

  get summaryRows() {
    const rows = [
      {
        label: i18n("user.invited.invite_roles.summary.role"),
        value: this.summaryRoleValue,
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

  get submitDisabled() {
    return this.saving || this.submitForcedDisabled;
  }

  get isLinkCreation() {
    return !this.inviteCreated && !this.isEmailDelivery;
  }

  get emailFieldLabel() {
    return this.isAdminInvite
      ? i18n("user.invited.invite_roles.admin_email_label")
      : i18n("user.invited.invite_roles.member_email_label");
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
  onStaffRoleChange(value, { set }) {
    set("staffRole", value);
    this.staffRole = value;
  }

  @action
  setDelivery(value) {
    this.delivery = value;
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
      description: data.description,
      custom_message: data.customMessage,
      expires_at: this.expiresAtFrom(data),
    };

    if (!wasCreated) {
      if (this.staffRole === "moderator") {
        submitData.is_moderator = true;
      } else {
        submitData.is_admin = true;
      }
    }

    if (this.delivery === "email") {
      submitData.email = data.email?.trim();
    } else {
      // a cleared field arrives as null, and an undefined value would be
      // dropped from the request, leaving the existing domain in place
      submitData.domain = data.domain?.trim() ?? "";
      submitData.max_redemptions_allowed = data.maxRedemptions;
      submitData.skip_email = true;
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
      // a cleared field arrives as null, and an undefined value would be
      // dropped from the request, leaving the existing domain in place
      submitData.domain = data.domain?.trim() ?? "";
      submitData.max_redemptions_allowed = data.maxRedemptions;
      submitData.skip_email = true;
    }

    await this.save(submitData, nextScreen);
  }

  @action
  async submitForm() {
    this.linkAutoCopied = false;

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

        this.linkAutoCopied = true;
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
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{this.title}}
    >
      <:belowHeader>
        {{#if this.flashText}}
          <div class="alert alert-error" id="modal-alert" role="alert">
            {{trustHTML this.flashText}}
          </div>
        {{/if}}
      </:belowHeader>
      <:body>
        {{#if (eq this.screen "form")}}
          {{#if this.canChooseRole}}
            <div class="create-invite-with-roles-modal__role">
              <DSegmentedControl
                class="--full-width"
                @items={{this.roleItems}}
                @label="user.invited.invite_roles.role_label"
                @name="invite-role"
                @onSelect={{this.onRoleChange}}
                @value={{this.role}}
              />
            </div>
          {{/if}}

          {{#if this.isAdminInvite}}
            <PluginOutlet
              @connectorTagName="div"
              @name="create-invite-admin-mode"
              @outletArgs={{lazyHash
                invite=this.invite
                setSubmitDisabled=this.setSubmitDisabled
              }}
            />

            <Form
              class={{dConcatClass
                "create-invite-with-roles-modal__admin-form"
                (if this.submitDisabled "--disabled" "")
              }}
              @data={{this.adminFormData}}
              @onRegisterApi={{this.registerApi}}
              @onSubmit={{this.onAdminFormSubmit}}
              as |form|
            >
              {{#unless this.inviteCreated}}
                <form.Field
                  @format="full"
                  @name="staffRole"
                  @onSet={{this.onStaffRoleChange}}
                  @showTitle={{false}}
                  @title={{this.staffRoleLabel}}
                  @type="radio-group"
                  as |field|
                >
                  <field.Control
                    class="--inline"
                    disabled={{this.submitDisabled}}
                    @title={{this.staffRoleLabel}}
                    as |radioGroup|
                  >
                    {{#each this.staffRoleItems as |item|}}
                      <radioGroup.Radio
                        @value={{item.value}}
                      >{{item.label}}</radioGroup.Radio>
                    {{/each}}

                    <p
                      class="create-invite-with-roles-modal__staff-role-description"
                    >
                      {{this.staffRoleDescription}}
                    </p>
                  </field.Control>
                </form.Field>
              {{/unless}}

              <form.ConditionalContent
                @activeName={{this.delivery}}
                @onChange={{this.setDelivery}}
                as |conditional|
              >
                {{#unless this.inviteCreated}}
                  <fieldset>
                    <legend class="form-kit__fieldset-title">{{i18n
                        "user.invited.invite_roles.invite_by"
                      }}</legend>
                    <conditional.Conditions as |Condition|>
                      <Condition @name="link">{{i18n
                          "user.invited.invite_roles.invite_by_link"
                        }}</Condition>
                      {{#if this.allowEmailInvites}}
                        <Condition @name="email">{{i18n
                            "user.invited.invite_roles.invite_by_email"
                          }}</Condition>
                      {{/if}}
                    </conditional.Conditions>
                  </fieldset>
                {{/unless}}

                <conditional.Contents as |Content|>
                  <Content @name="link">
                    {{#if this.showAdvanced}}
                      <form.Field
                        @description={{i18n
                          "user.invited.invite_roles.restrict_domain_help"
                        }}
                        @format="full"
                        @name="domain"
                        @title={{i18n
                          "user.invited.invite_roles.restrict_domain"
                        }}
                        @type="input"
                        @validate={{if
                          (eq this.delivery "link")
                          this.validateDomain
                        }}
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
                  </Content>

                  <Content @name="email">
                    <form.Field
                      @description={{i18n
                        "user.invited.invite_roles.member_email_help"
                      }}
                      @disabled={{this.inviteCreated}}
                      @format="full"
                      @name="email"
                      @title={{this.emailFieldLabel}}
                      @type="input-email"
                      @validate={{if
                        (eq this.delivery "email")
                        this.validateEmail
                      }}
                      @validation={{if (eq this.delivery "email") "required"}}
                      as |field|
                    >
                      <field.Control
                        autocomplete="off"
                        data-1p-ignore
                        data-lpignore="true"
                        placeholder={{i18n
                          "user.invited.invite_roles.email_placeholder"
                        }}
                      />
                    </form.Field>
                  </Content>
                </conditional.Contents>
              </form.ConditionalContent>

              {{#if this.showAdvanced}}
                <form.Field
                  @description={{i18n "user.invited.invite.description_help"}}
                  @format="full"
                  @name="description"
                  @title={{i18n "user.invited.invite.description"}}
                  @type="input"
                  @validation={{this.descriptionValidation}}
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <form.Field
                  @description={{i18n
                    "user.invited.invite.custom_message_help"
                  }}
                  @format="full"
                  @name="customMessage"
                  @title={{i18n "user.invited.invite.custom_message"}}
                  @type="textarea"
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
                  @created={{this.inviteCreated}}
                  @form={{form}}
                  @options={{this.expireAfterOptions}}
                />
              {{/if}}
            </Form>
          {{else}}
            <Form
              class="create-invite-with-roles-modal__member-form"
              @data={{this.memberFormData}}
              @onRegisterApi={{this.registerApi}}
              @onSubmit={{this.onMemberFormSubmit}}
              as |form|
            >
              <form.ConditionalContent
                @activeName={{this.delivery}}
                @onChange={{this.setDelivery}}
                as |conditional|
              >
                {{#unless this.inviteCreated}}
                  <fieldset>
                    <legend class="form-kit__fieldset-title">{{i18n
                        "user.invited.invite_roles.invite_by"
                      }}</legend>
                    <conditional.Conditions as |Condition|>
                      <Condition @name="link">{{i18n
                          "user.invited.invite_roles.invite_by_link"
                        }}</Condition>
                      {{#if this.allowEmailInvites}}
                        <Condition @name="email">{{i18n
                            "user.invited.invite_roles.invite_by_email"
                          }}</Condition>
                      {{/if}}
                    </conditional.Conditions>
                  </fieldset>
                {{/unless}}

                <conditional.Contents as |Content|>
                  <Content @name="link">
                    {{#if this.showAdvanced}}
                      <form.Field
                        @description={{i18n
                          "user.invited.invite_roles.restrict_domain_help"
                        }}
                        @format="full"
                        @name="domain"
                        @title={{i18n
                          "user.invited.invite_roles.restrict_domain"
                        }}
                        @type="input"
                        @validate={{if
                          (eq this.delivery "link")
                          this.validateDomain
                        }}
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
                  </Content>

                  <Content @name="email">
                    <form.Field
                      @description={{i18n
                        "user.invited.invite_roles.member_email_help"
                      }}
                      @disabled={{this.inviteCreated}}
                      @format="full"
                      @name="email"
                      @title={{this.emailFieldLabel}}
                      @type="input-email"
                      @validate={{if
                        (eq this.delivery "email")
                        this.validateEmail
                      }}
                      @validation={{if (eq this.delivery "email") "required"}}
                      as |field|
                    >
                      <field.Control
                        autocomplete="off"
                        data-1p-ignore
                        data-lpignore="true"
                        placeholder={{i18n
                          "user.invited.invite_roles.email_placeholder"
                        }}
                      />
                    </form.Field>
                  </Content>
                </conditional.Contents>
              </form.ConditionalContent>

              {{#if this.showAdvanced}}
                {{#if (eq this.delivery "email")}}
                  <form.Field
                    @description={{i18n
                      "user.invited.invite.custom_message_help"
                    }}
                    @format="full"
                    @name="customMessage"
                    @title={{i18n "user.invited.invite.custom_message"}}
                    @type="textarea"
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
                    @format="small"
                    @name="maxRedemptions"
                    @title={{i18n
                      "user.invited.invite.max_redemptions_allowed"
                    }}
                    @type="input-number"
                    @validation="required"
                    as |field|
                  >
                    <field.Control
                      max={{this.maxRedemptionsAllowedLimit}}
                      min="1"
                    />
                  </form.Field>
                {{/if}}

                <form.Field
                  @description={{i18n "user.invited.invite.description_help"}}
                  @format="full"
                  @name="description"
                  @title={{i18n "user.invited.invite.description"}}
                  @type="input"
                  @validation={{this.descriptionValidation}}
                  as |field|
                >
                  <field.Control />
                </form.Field>

                <ExpiryField
                  @created={{this.inviteCreated}}
                  @form={{form}}
                  @options={{this.expireAfterOptions}}
                />

                {{#if this.canArriveAtTopic}}
                  <form.Field
                    @description={{i18n
                      "user.invited.invite_roles.arrive_at_topic_help"
                    }}
                    @format="full"
                    @name="inviteToTopic"
                    @title={{i18n "user.invited.invite.invite_to_topic"}}
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <TopicChooser
                        @content={{this.topics}}
                        @onChange={{fn this.onChangeTopic field.set}}
                        @options={{hash additionalFilters="status:public"}}
                        @value={{field.value}}
                      />
                    </field.Control>
                  </form.Field>
                {{/if}}

                {{#if this.canInviteToGroup}}
                  <form.Field
                    @format="full"
                    @name="inviteToGroups"
                    @title={{i18n "user.invited.invite.add_to_groups"}}
                    @type="custom"
                    as |field|
                  >
                    <field.Control>
                      <GroupChooser
                        @content={{this.allGroups}}
                        @labelProperty="name"
                        @onChange={{field.set}}
                        @value={{field.value}}
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
              <ShareOrCopyInviteLink
                @invite={{this.invite}}
                @isCopied={{this.linkAutoCopied}}
              />
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
            class="btn-primary save-invite"
            @action={{this.submitForm}}
            @disabled={{this.submitDisabled}}
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
          />
          <DButton
            class="btn-transparent cancel-button"
            disabled={{this.submitDisabled}}
            @action={{this.cancel}}
            @label="user.invited.invite.cancel"
          />
          <AdvancedModeToggle
            disabled={{this.submitDisabled}}
            @active={{this.showAdvanced}}
            @onToggle={{this.toggleAdvanced}}
          />
        {{else if (eq this.screen "summary")}}
          <DButton
            class="btn-default edit-invite"
            @action={{this.editInvite}}
            @translatedLabel={{i18n "user.invited.invite_roles.summary.edit"}}
          />
          <LinkTo
            class="btn btn-default view-invites"
            @models={{array this.currentUser.username_lower "pending"}}
            @route="userInvited.show"
          >
            {{i18n "user.invited.invite_roles.summary.view_invites"}}
          </LinkTo>
        {{else}}
          <LinkTo
            class="btn btn-default view-invites"
            @models={{array this.currentUser.username_lower "pending"}}
            @route="userInvited.show"
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
      @format="full"
      @name="expiresAt"
      @title={{i18n "user.invited.invite.expires_at"}}
      @type="custom"
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
      @format="full"
      @name="expiresAfterDays"
      @title={{i18n "user.invited.invite.expires_after"}}
      @type="select"
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
      class="invite-link"
      name="invite-link"
      readonly={{true}}
      type="text"
      value={{@invite.link}}
    />
    {{#if (canNativeShare this.capabilities)}}
      <DButton
        class="btn-primary"
        @action={{this.nativeShare}}
        @icon="share"
        @translatedLabel={{i18n "user.invited.invite.share_link"}}
      />
    {{else}}
      <DCopyButton
        @isCopied={{@isCopied}}
        @selector="input.invite-link"
        @translatedLabel={{i18n "user.invited.invite.copy_link"}}
        @translatedLabelAfterCopy={{i18n "user.invited.invite.link_copied"}}
      />
    {{/if}}
  </template>
}

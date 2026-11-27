import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const t = (key, options) =>
  i18n(themePrefix(`channel_privacy.${key}`), options);

/**
 * Who can see a channel, after it's made: the create modal's private switch
 * and groups, filled in from the channel as it is now.
 */
export default class ChannelPrivacyModal extends Component {
  @service toasts;

  @tracked flash;
  @tracked formData;
  @tracked loaded;
  @tracked submitting = false;
  formApi;

  constructor() {
    super(...arguments);

    if (this.privacy.kind !== "shared") {
      this.#load();
    }
  }

  get privacy() {
    return this.args.model.privacy;
  }

  get loading() {
    return !this.formData && !this.flash;
  }

  // The groups a subcategory's access requires are added on save, so they
  // aren't offered; nor are groups the parent category doesn't allow.
  get groupOptions() {
    const required = new Set((this.loaded?.required || []).map((g) => g.id));
    const allowed = this.loaded?.allowedGroupIds;

    return this.args.model.groups.filter(
      (group) => !required.has(group.id) && (!allowed || allowed.has(group.id))
    );
  }

  // The parent's name links to its security settings, where what it allows
  // can be changed.
  get parentLink() {
    const { name, securityUrl } = this.loaded.privateParent;
    return `<a class="concord-channel-privacy-modal__parent" href="${escapeExpression(securityUrl)}">${escapeExpression(name)}</a>`;
  }

  // Its parent decides as much as it does, so say which way and why.
  get privateDescription() {
    const { publicSubcategory, privateParent } = this.loaded || {};

    if (publicSubcategory) {
      return t("public_subcategory", { name: publicSubcategory });
    }
    if (privateParent) {
      return trustHTML(t("private_parent", { name: this.parentLink }));
    }
    return i18n(themePrefix("create_channel.private_description"));
  }

  get privacyLocked() {
    return !!(this.loaded?.publicSubcategory || this.loaded?.privateParent);
  }

  get groupsDescription() {
    const { required = [], privateParent } = this.loaded || {};
    const notes = [];

    if (privateParent) {
      notes.push(
        t("parent_groups", {
          name: this.parentLink,
          groups: escapeExpression(privateParent.groupNames.join(", ")),
        })
      );
    }
    if (required.length) {
      notes.push(
        t("required_groups", {
          groups: escapeExpression(
            required.map((group) => group.name).join(", ")
          ),
        })
      );
    }
    if (this.privacy.kind === "voice") {
      notes.push(t("voice_note"));
    }

    return notes.length ? trustHTML(notes.join(" ")) : null;
  }

  get sharedCategoryName() {
    return this.privacy.category?.displayName;
  }

  @action
  validate(data, { addError }) {
    if (
      this.privacy.requiresGroups &&
      data.isPrivate &&
      !data.groupIds?.length &&
      !this.loaded?.required?.length
    ) {
      addError("groupIds", {
        title: i18n(themePrefix("create_channel.groups")),
        message: i18n(themePrefix("create_channel.groups_required")),
      });
    }
  }

  @action
  async save(data) {
    this.flash = null;

    try {
      const notice = await this.privacy.save(data, this.loaded);
      this.args.closeModal();

      if (notice) {
        this.toasts.warning({ data: { message: notice } });
      }
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  @action
  closeOnParentLink(event) {
    if (event.target.closest(".concord-channel-privacy-modal__parent")) {
      this.args.closeModal();
    }
  }

  @action
  openCategorySecurity() {
    this.args.closeModal();
    DiscourseURL.routeTo(
      `/c/${Category.slugFor(this.privacy.category)}/edit/security`
    );
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  // The buttons sit in the modal's fixed footer, outside the form, which
  // only renders once the permissions have loaded.
  @action
  async submit() {
    this.submitting = true;
    try {
      await this.formApi?.submit();
    } finally {
      this.submitting = false;
    }
  }

  async #load() {
    try {
      this.loaded = await this.privacy.load();
      this.formData = {
        isPrivate: this.loaded.isPrivate,
        groupIds: this.loaded.groupIds,
      };
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  <template>
    <DModal
      class="concord-create-channel-modal concord-channel-privacy-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{t "title" name=@model.name}}
    >
      <:body>
        {{#if (eq this.privacy.kind "shared")}}
          <p class="concord-channel-privacy-modal__shared">
            {{t "shared" category=this.sharedCategoryName}}
          </p>
        {{else}}
          {{! eslint-disable ember/template-no-invalid-interactive }}
          <div {{on "click" this.closeOnParentLink}}>
            <DConditionalLoadingSpinner @condition={{this.loading}}>
              {{#if this.formData}}
                <Form
                  @data={{this.formData}}
                  @onRegisterApi={{this.registerApi}}
                  @onSubmit={{this.save}}
                  @validate={{this.validate}}
                  as |form data|
                >
                  <form.Field
                    @description={{this.privateDescription}}
                    @disabled={{this.privacyLocked}}
                    @format="full"
                    @name="isPrivate"
                    @title={{i18n (themePrefix "create_channel.private")}}
                    @type="toggle"
                    as |field|
                  >
                    <field.Control />
                  </form.Field>

                  {{#if data.isPrivate}}
                    <form.Field
                      @description={{this.groupsDescription}}
                      @format="full"
                      @name="groupIds"
                      @title={{if
                        (eq this.privacy.kind "voice")
                        (t "voice_groups")
                        (i18n (themePrefix "create_channel.groups"))
                      }}
                      @type="custom"
                      as |field|
                    >
                      <field.Control>
                        <GroupChooser
                          @content={{this.groupOptions}}
                          @labelProperty="name"
                          @onChange={{field.set}}
                          @value={{field.value}}
                        />
                      </field.Control>
                    </form.Field>
                  {{/if}}
                </Form>
              {{/if}}
            </DConditionalLoadingSpinner>
          </div>
        {{/if}}
      </:body>
      <:footer>
        {{#if (eq this.privacy.kind "shared")}}
          <DButton
            class="btn-primary"
            @action={{this.openCategorySecurity}}
            @translatedLabel={{t "open_category"}}
          />
        {{else}}
          <DButton
            class="btn-primary"
            @action={{this.submit}}
            @disabled={{this.loading}}
            @isLoading={{this.submitting}}
            @label="save"
          />
        {{/if}}
        <DButton
          class="btn-transparent"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}

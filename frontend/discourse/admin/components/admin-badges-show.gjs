import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action, getProperties } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import AdminBadgesList from "discourse/admin/components/admin-badges-list";
import BadgePreviewModal from "discourse/admin/components/modal/badge-preview";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { sanitize } from "discourse/lib/text";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import { i18n } from "discourse-i18n";

const FORM_FIELDS = [
  "allow_title",
  "multiple_grant",
  "listable",
  "auto_revoke",
  "enabled",
  "show_posts",
  "target_posts",
  "name",
  "description",
  "long_description",
  "icon",
  "image_upload_id",
  "image_url",
  "query",
  "badge_grouping_id",
  "trigger",
  "badge_type_id",
  "show_in_post_header",
];

export default class AdminBadgesShow extends Component {
  @service adminBadges;
  @service dialog;
  @service modal;
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked previewLoading = false;

  get badges() {
    return this.adminBadges.badges;
  }

  get badgeTypes() {
    return this.adminBadges.badgeTypes;
  }

  get badgeGroupings() {
    return this.adminBadges.badgeGroupings;
  }

  get badgeTriggers() {
    return this.adminBadges.badgeTriggers;
  }

  get readOnly() {
    return this.args.badge.system;
  }

  get textCustomizationPrefix() {
    return `badges.${this.args.badge.i18n_name}.`;
  }

  // Form methods.
  @cached
  get formData() {
    const data = getProperties(this.args.badge, ...FORM_FIELDS);

    if (data.icon === "") {
      data.icon = undefined;
    }

    return data;
  }

  @action
  currentBadgeGrouping(data) {
    return this.adminBadges.badgeGroupings.find(
      (bg) => bg.id === data.badge_grouping_id
    )?.name;
  }

  sanitizeDescription(text) {
    return trustHTML(sanitize(text));
  }

  hasQuery(query) {
    return query?.trim?.()?.length > 0;
  }

  @action
  postHeaderDescription(data) {
    return this.disableBadgeOnPosts(data) && !data.system;
  }

  @action
  disableBadgeOnPosts(data) {
    const { listable, show_posts } = data;
    return !listable || !show_posts;
  }

  @action
  onSetImage(upload, { set }) {
    if (upload) {
      set("image_upload_id", upload.id);
      set("image_url", getURL(upload.url));
      set("icon", null);
    } else {
      set("image_upload_id", "");
      set("image_url", "");
    }
  }

  @action
  onSetIcon(value, { set }) {
    set("icon", value);
    set("image_upload_id", "");
    set("image_url", "");
  }

  @action
  showPreview(badge, explain, event) {
    event?.preventDefault();
    this.preview(badge, explain);
  }

  @action
  async preview(badge, explain) {
    try {
      this.previewLoading = true;
      const model = await ajax("/admin/badges/preview.json", {
        type: "POST",
        data: {
          sql: badge.query,
          target_posts: !!badge.target_posts,
          trigger: badge.trigger,
          explain,
        },
      });

      this.modal.show(BadgePreviewModal, { model: { badge: model } });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
      this.dialog.alert("Network error");
    } finally {
      this.previewLoading = false;
    }
  }

  @action
  validateForm(data, { addError, removeError }) {
    if (!data.icon && !data.image_url) {
      addError("icon", {
        title: "Icon",
        message: i18n("admin.badges.icon_or_image"),
      });
      addError("image_url", {
        title: "Image",
        message: i18n("admin.badges.icon_or_image"),
      });
    } else {
      removeError("image_url");
      removeError("icon");
    }
  }

  @action
  async handleSubmit(formData) {
    let fields = FORM_FIELDS;

    if (formData.system) {
      const protectedFields = this.protectedSystemFields || [];
      fields = fields.filter((f) => !protectedFields.includes(f));
    }

    const data = {};
    fields.forEach(function (field) {
      data[field] = formData[field];
    });

    const newBadge = !this.args.badge.id;

    try {
      const badge = await this.args.badge.save(data);

      this.toasts.success({ data: { message: i18n("saved") } });

      if (newBadge) {
        const adminBadges = this.adminBadges.badges;
        if (!adminBadges.includes(badge)) {
          adminBadges.push(badge);
        }
        return this.router.transitionTo("adminBadges.show", badge.id);
      }
    } catch (error) {
      return popupAjaxError(error);
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  async handleDelete() {
    if (!this.args.badge?.id) {
      return this.router.transitionTo("adminBadges.index");
    }

    return this.dialog.deleteConfirm({
      title: i18n("admin.badges.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.formApi.reset();
          await this.args.badge.destroy();
          this.adminBadges.badges = this.adminBadges.badges.filter(
            (badge) => badge.id !== this.args.badge.id
          );
          this.router.transitionTo("adminBadges.index");
        } catch {
          this.dialog.alert(i18n("generic_error"));
        }
      },
    });
  }

  <template>
    <AdminBadgesList @badges={{this.badges}} />
    {{#if @badge}}
      <Form
        class="badge-form current-badge content-body"
        @data={{this.formData}}
        @onRegisterApi={{this.registerApi}}
        @onSubmit={{this.handleSubmit}}
        @validate={{this.validateForm}}
        as |form data|
      >

        <h2 class="current-badge-header">
          {{dIconOrImage data}}
          <span class="badge-display-name">{{data.name}}</span>
        </h2>

        <form.Field
          @name="enabled"
          @title={{i18n "admin.badges.status"}}
          @type="question"
          @validation="required"
          as |field|
        >
          <field.Control
            @noLabel={{i18n "admin.badges.disabled"}}
            @yesLabel={{i18n "admin.badges.enabled"}}
          />
        </form.Field>

        {{#if this.readOnly}}
          <form.Container data-name="name" @title={{i18n "admin.badges.name"}}>
            <span class="readonly-field">
              {{@badge.name}}
            </span>
            <LinkTo
              @query={{hash q=(concat this.textCustomizationPrefix "name")}}
              @route="adminSiteText"
            >
              {{dIcon "pencil"}}
            </LinkTo>
          </form.Container>
        {{else}}
          <form.Field
            @disabled={{this.readOnly}}
            @name="name"
            @title={{i18n "admin.badges.name"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control />
          </form.Field>
        {{/if}}

        <form.Section @title={{i18n "admin.badges.sections.design"}}>
          <form.Field
            @disabled={{this.readOnly}}
            @name="badge_type_id"
            @title={{i18n "admin.badges.badge_type"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control as |select|>
              {{#each this.badgeTypes as |badgeType|}}
                <select.Option @value={{badgeType.id}}>
                  {{badgeType.name}}
                </select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          <form.ConditionalContent
            @activeName={{if data.image_url "upload-image" "choose-icon"}}
            as |cc|
          >
            <cc.Conditions as |Condition|>
              <Condition @name="choose-icon">
                {{i18n "admin.badges.select_an_icon"}}
              </Condition>
              <Condition @name="upload-image">
                {{i18n "admin.badges.upload_an_image"}}
              </Condition>
            </cc.Conditions>
            <cc.Contents as |Content|>
              <Content @name="choose-icon">
                <form.Field
                  @format="small"
                  @name="icon"
                  @onSet={{this.onSetIcon}}
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.icon"}}
                  @type="icon"
                  as |field|
                >
                  <field.Control @onlyAvailable={{false}} />
                </form.Field>
              </Content>
              <Content @name="upload-image">
                <form.Field
                  @name="image_url"
                  @onSet={{this.onSetImage}}
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.image"}}
                  @type="image"
                  as |field|
                >
                  <field.Control @type="badge_image" />
                </form.Field>
              </Content>
            </cc.Contents>
          </form.ConditionalContent>

          {{#if this.readOnly}}
            <form.Container
              data-name="description"
              @title={{i18n "admin.badges.description"}}
            >
              <span class="readonly-field">
                {{this.sanitizeDescription @badge.description}}
              </span>
              <LinkTo
                @query={{hash
                  q=(concat this.textCustomizationPrefix "description")
                }}
                @route="adminSiteText"
              >
                {{dIcon "pencil"}}
              </LinkTo>
            </form.Container>
          {{else}}
            <form.Field
              @disabled={{this.readOnly}}
              @name="description"
              @title={{i18n "admin.badges.description"}}
              @type="textarea"
              as |field|
            >
              <field.Control />
            </form.Field>
          {{/if}}

          {{#if this.readOnly}}
            <form.Container
              data-name="long_description"
              @title={{i18n "admin.badges.long_description"}}
            >
              <span class="readonly-field">
                {{this.sanitizeDescription @badge.long_description}}
              </span>

              <LinkTo
                @query={{hash
                  q=(concat this.textCustomizationPrefix "long_description")
                }}
                @route="adminSiteText"
              >
                {{dIcon "pencil"}}
              </LinkTo>
            </form.Container>
          {{else}}
            <form.Field
              @disabled={{this.readOnly}}
              @name="long_description"
              @title={{i18n "admin.badges.long_description"}}
              @type="textarea"
              as |field|
            >
              <field.Control />
            </form.Field>
          {{/if}}
        </form.Section>

        {{#if this.siteSettings.enable_badge_sql}}
          <form.Section @title={{i18n "admin.badges.sections.query"}}>
            <form.Field
              @disabled={{this.readOnly}}
              @format="full"
              @name="query"
              @title={{i18n "admin.badges.query"}}
              @type="code"
              as |field|
            >
              <field.Control @lang="sql" />
            </form.Field>

            {{#if (this.hasQuery data.query)}}
              <form.Container>
                <form.Button
                  class="preview-badge"
                  @action={{fn this.showPreview data "false"}}
                  @isLoading={{this.previewLoading}}
                  @label="admin.badges.preview.link_text"
                />
                <form.Button
                  class="preview-badge-plan"
                  @action={{fn this.showPreview data "true"}}
                  @isLoading={{this.previewLoading}}
                  @label="admin.badges.preview.plan_text"
                />
              </form.Container>

              <form.CheckboxGroup as |group|>
                <group.Field
                  @disabled={{this.readOnly}}
                  @name="auto_revoke"
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.auto_revoke"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </group.Field>

                <group.Field
                  @disabled={{this.readOnly}}
                  @name="target_posts"
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.target_posts"}}
                  @type="checkbox"
                  as |field|
                >
                  <field.Control />
                </group.Field>
              </form.CheckboxGroup>

              <form.Field
                @disabled={{this.readOnly}}
                @name="trigger"
                @title={{i18n "admin.badges.trigger"}}
                @type="select"
                @validation="required"
                as |field|
              >
                <field.Control as |select|>
                  {{#each this.badgeTriggers as |badgeTrigger|}}
                    <select.Option @value={{badgeTrigger.id}}>
                      {{badgeTrigger.name}}
                    </select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>
            {{/if}}
          </form.Section>
        {{/if}}

        <form.Section @title={{i18n "admin.badges.sections.settings"}}>
          <form.Field
            @name="badge_grouping_id"
            @title={{i18n "admin.badges.badge_grouping"}}
            @type="menu"
            @validation="required"
            as |field|
          >
            <field.Control
              @selection={{this.currentBadgeGrouping data}}
              as |menu|
            >
              {{#each this.badgeGroupings as |grouping|}}
                <menu.Item @value={{grouping.id}}>{{grouping.name}}</menu.Item>
              {{/each}}
            </field.Control>
          </form.Field>

          <form.CheckboxGroup
            @title={{i18n "admin.badges.usage_heading"}}
            as |group|
          >
            <group.Field
              @format="full"
              @name="allow_title"
              @showTitle={{false}}
              @title={{i18n "admin.badges.allow_title"}}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </group.Field>

            <group.Field
              @disabled={{this.readOnly}}
              @format="full"
              @name="multiple_grant"
              @showTitle={{false}}
              @title={{i18n "admin.badges.multiple_grant"}}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </group.Field>
          </form.CheckboxGroup>

          <form.CheckboxGroup
            @title={{i18n "admin.badges.visibility_heading"}}
            as |group|
          >
            <group.Field
              @disabled={{this.readOnly}}
              @format="full"
              @name="listable"
              @showTitle={{false}}
              @title={{i18n "admin.badges.listable"}}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </group.Field>

            <group.Field
              @disabled={{this.readOnly}}
              @format="full"
              @name="show_posts"
              @showTitle={{false}}
              @title={{i18n "admin.badges.show_posts"}}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </group.Field>

            <group.Field
              @disabled={{this.disableBadgeOnPosts data}}
              @format="full"
              @name="show_in_post_header"
              @showTitle={{false}}
              @title={{i18n "admin.badges.show_in_post_header"}}
              @type="checkbox"
              as |field|
            >
              <field.Control>
                {{#if (this.postHeaderDescription data)}}
                  {{i18n "admin.badges.show_in_post_header_disabled"}}
                {{/if}}
              </field.Control>
            </group.Field>
          </form.CheckboxGroup>
        </form.Section>

        <PluginOutlet
          @name="admin-above-badge-buttons"
          @outletArgs={{lazyHash badge=@badge form=form}}
        />

        <form.Actions>
          <form.Submit />

          {{#unless this.readOnly}}
            <form.Button
              class="badge-form__delete-badge-btn btn-danger"
              @action={{this.handleDelete}}
            >
              {{i18n "admin.badges.delete"}}
            </form.Button>
          {{/unless}}
        </form.Actions>
      </Form>
    {{/if}}
  </template>
}

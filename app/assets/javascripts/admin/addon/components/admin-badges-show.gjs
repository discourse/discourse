import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action, getProperties } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import iconOrImage from "discourse/helpers/icon-or-image";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import AdminBadgesList from "admin/components/admin-badges-list";
import BadgePreviewModal from "admin/components/modal/badge-preview";

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

  @action
  currentBadgeGrouping(data) {
    return this.adminBadges.badgeGroupings.find(
      (bg) => bg.id === data.badge_grouping_id
    )?.name;
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

  hasQuery(query) {
    return query?.trim?.()?.length > 0;
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
        @data={{this.formData}}
        @onSubmit={{this.handleSubmit}}
        @validate={{this.validateForm}}
        @onRegisterApi={{this.registerApi}}
        class="badge-form current-badge content-body"
        as |form data|
      >

        <h2 class="current-badge-header">
          {{iconOrImage data}}
          <span class="badge-display-name">{{data.name}}</span>
        </h2>

        <form.Field
          @name="enabled"
          @validation="required"
          @title={{i18n "admin.badges.status"}}
          as |field|
        >
          <field.Question
            @yesLabel={{i18n "admin.badges.enabled"}}
            @noLabel={{i18n "admin.badges.disabled"}}
          />
        </form.Field>

        {{#if this.readOnly}}
          <form.Container data-name="name" @title={{i18n "admin.badges.name"}}>
            <span class="readonly-field">
              {{@badge.name}}
            </span>
            <LinkTo
              @route="adminSiteText"
              @query={{hash q=(concat this.textCustomizationPrefix "name")}}
            >
              {{icon "pencil"}}
            </LinkTo>
          </form.Container>
        {{else}}
          <form.Field
            @title={{i18n "admin.badges.name"}}
            @name="name"
            @disabled={{this.readOnly}}
            @validation="required"
            as |field|
          >
            <field.Input />
          </form.Field>
        {{/if}}

        <form.Section @title="Design">
          <form.Field
            @name="badge_type_id"
            @title={{i18n "admin.badges.badge_type"}}
            @validation="required"
            @disabled={{this.readOnly}}
            as |field|
          >
            <field.Select as |select|>
              {{#each this.badgeTypes as |badgeType|}}
                <select.Option @value={{badgeType.id}}>
                  {{badgeType.name}}
                </select.Option>
              {{/each}}
            </field.Select>
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
                  @title={{i18n "admin.badges.icon"}}
                  @showTitle={{false}}
                  @name="icon"
                  @onSet={{this.onSetIcon}}
                  @format="small"
                  as |field|
                >
                  <field.Icon />
                </form.Field>
              </Content>
              <Content @name="upload-image">
                <form.Field
                  @name="image_url"
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.image"}}
                  @onSet={{this.onSetImage}}
                  as |field|
                >
                  <field.Image @type="badge_image" />
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
                {{@badge.description}}
              </span>
              <LinkTo
                @route="adminSiteText"
                @query={{hash
                  q=(concat this.textCustomizationPrefix "description")
                }}
              >
                {{icon "pencil"}}
              </LinkTo>
            </form.Container>
          {{else}}
            <form.Field
              @title={{i18n "admin.badges.description"}}
              @name="description"
              @disabled={{this.readOnly}}
              as |field|
            >
              <field.Textarea />
            </form.Field>
          {{/if}}

          {{#if this.readOnly}}
            <form.Container
              data-name="long_description"
              @title={{i18n "admin.badges.long_description"}}
            >
              <span class="readonly-field">
                {{@badge.long_description}}
              </span>

              <LinkTo
                @route="adminSiteText"
                @query={{hash
                  q=(concat this.textCustomizationPrefix "long_description")
                }}
              >
                {{icon "pencil"}}
              </LinkTo>
            </form.Container>
          {{else}}
            <form.Field
              @name="long_description"
              @title={{i18n "admin.badges.long_description"}}
              @disabled={{this.readOnly}}
              as |field|
            >
              <field.Textarea />
            </form.Field>
          {{/if}}
        </form.Section>

        {{#if this.siteSettings.enable_badge_sql}}
          <form.Section @title="Query">
            <form.Field
              @name="query"
              @title={{i18n "admin.badges.query"}}
              @disabled={{this.readOnly}}
              @format="full"
              as |field|
            >
              <field.Code @lang="sql" />
            </form.Field>

            {{#if (this.hasQuery data.query)}}
              <form.Container>
                <form.Button
                  @isLoading={{this.previewLoading}}
                  @label="admin.badges.preview.link_text"
                  class="preview-badge"
                  @action={{fn this.showPreview data "false"}}
                />
                <form.Button
                  @isLoading={{this.previewLoading}}
                  @label="admin.badges.preview.plan_text"
                  class="preview-badge-plan"
                  @action={{fn this.showPreview data "true"}}
                />
              </form.Container>

              <form.CheckboxGroup as |group|>
                <group.Field
                  @name="auto_revoke"
                  @disabled={{this.readOnly}}
                  @showTitle={{false}}
                  @title={{i18n "admin.badges.auto_revoke"}}
                  as |field|
                >
                  <field.Checkbox />
                </group.Field>

                <group.Field
                  @name="target_posts"
                  @disabled={{this.readOnly}}
                  @title={{i18n "admin.badges.target_posts"}}
                  @showTitle={{false}}
                  as |field|
                >
                  <field.Checkbox />
                </group.Field>
              </form.CheckboxGroup>

              <form.Field
                @name="trigger"
                @disabled={{this.readOnly}}
                @validation="required"
                @title={{i18n "admin.badges.trigger"}}
                as |field|
              >
                <field.Select as |select|>
                  {{#each this.badgeTriggers as |badgeTrigger|}}
                    <select.Option @value={{badgeTrigger.id}}>
                      {{badgeTrigger.name}}
                    </select.Option>
                  {{/each}}
                </field.Select>
              </form.Field>
            {{/if}}
          </form.Section>
        {{/if}}

        <form.Section @title="Settings">
          <form.Field
            @name="badge_grouping_id"
            @disabled={{this.readOnly}}
            @validation="required"
            @title={{i18n "admin.badges.badge_grouping"}}
            as |field|
          >
            <field.Menu @selection={{this.currentBadgeGrouping data}} as |menu|>
              {{#each this.badgeGroupings as |grouping|}}
                <menu.Item @value={{grouping.id}}>{{grouping.name}}</menu.Item>
              {{/each}}
              <menu.Divider />
              <menu.Item @action={{routeAction "editGroupings"}}>Add new group</menu.Item>
            </field.Menu>
          </form.Field>

          <form.CheckboxGroup
            @title={{i18n "admin.badges.usage_heading"}}
            as |group|
          >
            <group.Field
              @title={{i18n "admin.badges.allow_title"}}
              @showTitle={{false}}
              @name="allow_title"
              @format="full"
              as |field|
            >
              <field.Checkbox />
            </group.Field>

            <group.Field
              @title={{i18n "admin.badges.multiple_grant"}}
              @showTitle={{false}}
              @name="multiple_grant"
              @disabled={{this.readOnly}}
              @format="full"
              as |field|
            >
              <field.Checkbox />
            </group.Field>
          </form.CheckboxGroup>

          <form.CheckboxGroup
            @title={{i18n "admin.badges.visibility_heading"}}
            as |group|
          >
            <group.Field
              @title={{i18n "admin.badges.listable"}}
              @showTitle={{false}}
              @name="listable"
              @disabled={{this.readOnly}}
              @format="full"
              as |field|
            >
              <field.Checkbox />
            </group.Field>

            <group.Field
              @title={{i18n "admin.badges.show_posts"}}
              @showTitle={{false}}
              @name="show_posts"
              @disabled={{this.readOnly}}
              @format="full"
              as |field|
            >
              <field.Checkbox />
            </group.Field>

            <group.Field
              @title={{i18n "admin.badges.show_in_post_header"}}
              @showTitle={{false}}
              @name="show_in_post_header"
              @disabled={{this.disableBadgeOnPosts data}}
              @format="full"
              as |field|
            >
              <field.Checkbox>
                {{#if (this.postHeaderDescription data)}}
                  {{i18n "admin.badges.show_in_post_header_disabled"}}
                {{/if}}
              </field.Checkbox>
            </group.Field>
          </form.CheckboxGroup>
        </form.Section>

        <PluginOutlet
          @name="admin-above-badge-buttons"
          @outletArgs={{lazyHash badge=this.buffered form=form}}
        />

        <form.Actions>
          <form.Submit />

          {{#unless this.readOnly}}
            <form.Button
              @action={{this.handleDelete}}
              class="badge-form__delete-badge-btn btn-danger"
            >
              {{i18n "admin.badges.delete"}}
            </form.Button>
          {{/unless}}
        </form.Actions>
      </Form>
    {{/if}}
  </template>
}

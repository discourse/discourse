import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import iconOrImage from "discourse/helpers/icon-or-image";
import number from "discourse/helpers/number";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default class AdminBadgesShow extends Component {
  <template>
    <Form
      @data={{@controller.formData}}
      @onSubmit={{@controller.handleSubmit}}
      @validate={{@controller.validateForm}}
      @onRegisterApi={{@controller.registerApi}}
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

      {{#if @controller.readOnly}}
        <form.Container data-name="name" @title={{i18n "admin.badges.name"}}>
          <span class="readonly-field">
            {{@controller.model.name}}
          </span>
          <LinkTo
            @route="adminSiteText"
            @query={{hash
              q=(concat @controller.textCustomizationPrefix "name")
            }}
          >
            {{icon "pencil"}}
          </LinkTo>
        </form.Container>
      {{else}}
        <form.Field
          @title={{i18n "admin.badges.name"}}
          @name="name"
          @disabled={{@controller.readOnly}}
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
          @disabled={{@controller.readOnly}}
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.badgeTypes as |badgeType|}}
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
                @onSet={{@controller.onSetIcon}}
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
                @onSet={{@controller.onSetImage}}
                @onUnset={{@controller.onUnsetImage}}
                as |field|
              >
                <field.Image @type="badge_image" />
              </form.Field>
            </Content>
          </cc.Contents>
        </form.ConditionalContent>

        {{#if @controller.readOnly}}
          <form.Container
            data-name="description"
            @title={{i18n "admin.badges.description"}}
          >
            <span class="readonly-field">
              {{@controller.model.description}}
            </span>
            <LinkTo
              @route="adminSiteText"
              @query={{hash
                q=(concat @controller.textCustomizationPrefix "description")
              }}
            >
              {{icon "pencil"}}
            </LinkTo>
          </form.Container>
        {{else}}
          <form.Field
            @title={{i18n "admin.badges.description"}}
            @name="description"
            @disabled={{@controller.readOnly}}
            as |field|
          >
            <field.Textarea />
          </form.Field>
        {{/if}}

        {{#if @controller.readOnly}}
          <form.Container
            data-name="long_description"
            @title={{i18n "admin.badges.long_description"}}
          >
            <span class="readonly-field">
              {{@controller.model.long_description}}
            </span>

            <LinkTo
              @route="adminSiteText"
              @query={{hash
                q=(concat
                  @controller.textCustomizationPrefix "long_description"
                )
              }}
            >
              {{icon "pencil"}}
            </LinkTo>
          </form.Container>
        {{else}}
          <form.Field
            @name="long_description"
            @title={{i18n "admin.badges.long_description"}}
            @disabled={{@controller.readOnly}}
            as |field|
          >
            <field.Textarea />
          </form.Field>
        {{/if}}
      </form.Section>

      {{#if @controller.siteSettings.enable_badge_sql}}
        <form.Section @title="Query">
          <form.Field
            @name="query"
            @title={{i18n "admin.badges.query"}}
            @disabled={{@controller.readOnly}}
            as |field|
          >
            <field.Code @lang="sql" />
          </form.Field>

          {{#if (@controller.hasQuery data.query)}}
            <form.Container>
              <form.Button
                @isLoading={{@controller.preview_loading}}
                @label="admin.badges.preview.link_text"
                class="preview-badge"
                @action={{fn @controller.showPreview data "false"}}
              />
              <form.Button
                @isLoading={{@controller.preview_loading}}
                @label="admin.badges.preview.plan_text"
                class="preview-badge-plan"
                @action={{fn @controller.showPreview data "true"}}
              />
            </form.Container>

            <form.CheckboxGroup as |group|>
              <group.Field
                @name="auto_revoke"
                @disabled={{@controller.readOnly}}
                @showTitle={{false}}
                @title={{i18n "admin.badges.auto_revoke"}}
                as |field|
              >
                <field.Checkbox />
              </group.Field>

              <group.Field
                @name="target_posts"
                @disabled={{@controller.readOnly}}
                @title={{i18n "admin.badges.target_posts"}}
                @showTitle={{false}}
                as |field|
              >
                <field.Checkbox />
              </group.Field>
            </form.CheckboxGroup>

            <form.Field
              @name="trigger"
              @disabled={{@controller.readOnly}}
              @validation="required"
              @title={{i18n "admin.badges.trigger"}}
              as |field|
            >
              <field.Select as |select|>
                {{#each @controller.badgeTriggers as |badgeType|}}
                  <select.Option @value={{badgeType.id}}>
                    {{badgeType.name}}
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
          @disabled={{@controller.readOnly}}
          @validation="required"
          @title={{i18n "admin.badges.badge_grouping"}}
          as |field|
        >
          <field.Menu
            @selection={{@controller.currentBadgeGrouping data}}
            as |menu|
          >
            {{#each @controller.badgeGroupings as |grouping|}}
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
            @disabled={{@controller.readOnly}}
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
            @disabled={{@controller.readOnly}}
            @format="full"
            as |field|
          >
            <field.Checkbox />
          </group.Field>

          <group.Field
            @title={{i18n "admin.badges.show_posts"}}
            @showTitle={{false}}
            @name="show_posts"
            @disabled={{@controller.readOnly}}
            @format="full"
            as |field|
          >
            <field.Checkbox />
          </group.Field>

          <group.Field
            @title={{i18n "admin.badges.show_in_post_header"}}
            @showTitle={{false}}
            @name="show_in_post_header"
            @disabled={{@controller.disableBadgeOnPosts data}}
            @format="full"
            as |field|
          >
            <field.Checkbox>
              {{#if (@controller.postHeaderDescription data)}}
                {{i18n "admin.badges.show_in_post_header_disabled"}}
              {{/if}}
            </field.Checkbox>
          </group.Field>
        </form.CheckboxGroup>
      </form.Section>

      <PluginOutlet
        @name="admin-above-badge-buttons"
        @outletArgs={{hash badge=@controller.buffered form=form}}
      />

      <form.Actions>
        <form.Submit />

        {{#unless @controller.readOnly}}
          <form.Button
            @action={{@controller.handleDelete}}
            class="badge-form__delete-badge-btn btn-danger"
          >
            {{i18n "admin.badges.delete"}}
          </form.Button>
        {{/unless}}
      </form.Actions>

      {{#if @controller.grant_count}}
        <div class="content-body current-badge-actions">
          <div>
            <LinkTo @route="badges.show" @model={{@controller}}>
              {{htmlSafe
                (i18n
                  "badges.awarded"
                  count=@controller.displayCount
                  number=(number @controller.displayCount)
                )
              }}
            </LinkTo>
          </div>
        </div>
      {{/if}}
    </Form>
  </template>
}

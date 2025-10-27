import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import CategoryList from "admin/components/site-settings/category-list";
import Color from "admin/components/site-settings/color";
import FontList from "admin/components/site-settings/font-list";
import GroupList from "admin/components/site-settings/group-list";
import HostList from "admin/components/site-settings/host-list";
import LocaleEnum from "admin/components/site-settings/locale-enum";
import TagList from "admin/components/site-settings/tag-list";
import ValueList from "admin/components/value-list";
import SiteSetting from "admin/models/site-setting";
import CategoryChooser from "select-kit/components/category-chooser";
import UserChooser from "select-kit/components/user-chooser";

class PrimaryActions extends Component {
  @service toasts;
  @service router;

  get cannotRevert() {
    return this.args.field.value === this.args.setting.default;
  }

  @action
  async revertToDefault(menu) {
    await menu.close();

    this.args.field.set(this.args.setting.default);
  }

  @action
  settingHistory() {
    this.router.transitionTo("adminLogs.staffActionLogs", {
      queryParams: {
        filters: {
          subject: this.args.setting.setting,
          action_name: "change_site_setting",
        },
        force_refresh: true,
      },
    });
  }

  @action
  async copySettingAsUrl(menu) {
    await menu.close();

    const url = `${window.location.origin}/admin/site_settings/category/all_results?filter=${this.args.setting.setting}`;

    try {
      await clipboardCopy(url);
      this.toasts.success({
        data: {
          message: i18n("admin.site_settings.actions.copied_to_clipboard"),
        },
      });
    } catch (error) {
      console.error("Failed to copy to clipboard:", error); // eslint-disable-line no-console
      this.toasts.error({
        data: {
          message: i18n("admin.site_settings.actions.failed_to_copy"),
        },
      });
    }
  }

  <template>
    <@actions.Menu
      @identifier={{concat "site-setting-menu-" @setting.setting}}
      @icon="gear"
      @class="btn-flat"
    >
      <:content as |menu|>
        <menu.Dropdown as |dropdown|>
          <dropdown.item>
            <DButton
              @disabled={{this.cannotRevert}}
              @action={{fn this.revertToDefault menu}}
              @label="admin.site_settings.actions.reset_setting"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{fn this.copySettingAsUrl menu}}
              @label="admin.site_settings.actions.copy_link"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              @action={{this.settingHistory}}
              @label="admin.site_settings.actions.setting_history"
            />
          </dropdown.item>
        </menu.Dropdown>
      </:content>
    </@actions.Menu>
  </template>
}

export default class FormKitSiteSettingWrapper extends Component {
  formApi = null;

  @cached
  get formData() {
    const data = {};
    this.args.settings.forEach((setting) => {
      let value = setting.value;
      if (setting.type === "bool") {
        value = value === true || value === "true";
      } else if (setting.type === "integer") {
        value = parseInt(value, 10);
      } else if (setting.type === "float") {
        value = parseFloat(value);
      }
      data[setting.setting] = value;
    });
    return data;
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  validateHexColor(name, color, helper) {
    // Allow empty values (for reset or optional colors)
    if (!color || color === "") {
      return;
    }

    const isValid = /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(color);
    if (!isValid) {
      const setting = this.args.settings.find((s) => s.setting === name);
      helper.addError(name, {
        title: setting?.humanized_name || name,
        message: i18n("admin.site_settings.validation.invalid_color"),
      });
    }
  }

  @action
  async save(data, options = {}) {
    if (!this.formApi) {
      return;
    }

    const params = {};
    const dirtyFields = new Set();

    if (options.patches) {
      options.patches.forEach((patch) => {
        if (patch.path && patch.path[0]) {
          dirtyFields.add(patch.path[0]);
        }
      });
    } else if (data) {
      Object.keys(data).forEach((key) => dirtyFields.add(key));
    }

    dirtyFields.forEach((key) => {
      const setting = this.args.settings.find((s) => s.setting === key);
      let value = this.formApi.get(key);

      if (setting?.type === "bool") {
        value = value ? "t" : "f";
      } else if (setting?.type === "integer" || setting?.type === "float") {
        value = String(value);
      }

      params[key] = {
        value,
        backfill: false,
      };
    });

    try {
      await SiteSetting.bulkUpdate(params);
    } catch (error) {
      const errorData = error.jqXHR?.responseJSON;
      if (errorData?.errors) {
        errorData.errors.forEach((errorMessage) => {
          const match = errorMessage.match(/^([^:]+):\s*(.+)$/);
          if (match) {
            const [, settingName, message] = match;
            const setting = this.args.settings.find(
              (s) => s.setting === settingName
            );
            this.formApi.addError(settingName, {
              title: setting?.humanized_name || settingName,
              message,
            });
          }
        });
      } else {
        throw error;
      }
    }
  }

  @action
  fieldFormat(settingType) {
    switch (settingType) {
      case "integer":
      case "float":
        return "medium";
      default:
        return "full";
    }
  }

  @action
  setValueList(set, delimiter, value) {
    set(value.join(delimiter));
  }

  @action
  setCategory(set, category) {
    set(category?.id);
  }

  @action
  getUsernameArray(value) {
    return value ? [value] : [];
  }

  @action
  setUsername(set, usernames) {
    set(usernames?.[0] || "");
  }

  @action
  isOverridden(setting) {
    if (!this.formApi) {
      return setting.overridden;
    }
    const currentValue = String(this.formApi.get(setting.setting) ?? "");
    const defaultValue = String(setting.default ?? "");
    return currentValue !== defaultValue;
  }

  <template>
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      @onRegisterApi={{this.onRegisterApi}}
      class="form-kit-settings-wrapper"
      as |form|
    >
      {{#each @settings as |setting|}}
        {{setting.type}}
        {{#if (eq setting.type "bool")}}
          <form.Field
            @name={{setting.setting}}
            @title={{setting.humanized_name}}
            @emphasis={{this.isOverridden setting}}
            @format={{this.fieldFormat setting.type}}
          >
            <:body as |field|>
              <field.Checkbox @label={{htmlSafe setting.description}}>
                <:primary-actions as |actions|>
                  <PrimaryActions
                    @form={{form}}
                    @field={{field}}
                    @actions={{actions}}
                    @setting={{setting}}
                    @save={{this.save}}
                  />
                </:primary-actions>
              </field.Checkbox>
            </:body>
          </form.Field>
        {{else if (eq setting.type "color")}}
          <form.Field
            @name={{setting.setting}}
            @title={{setting.humanized_name}}
            @emphasis={{this.isOverridden setting}}
            @format={{this.fieldFormat setting.type}}
            @validate={{this.validateHexColor}}
            as |field|
          >
            <field.Custom>
              <:body>
                <Color
                  @changeValueCallback={{field.set}}
                  @value={{field.value}}
                />
              </:body>
              <:primary-actions as |actions|>
                <PrimaryActions
                  @form={{form}}
                  @field={{field}}
                  @actions={{actions}}
                  @setting={{setting}}
                  @save={{this.save}}
                />
              </:primary-actions>
            </field.Custom>
          </form.Field>
        {{else}}
          <form.Field
            @name={{setting.setting}}
            @title={{setting.humanized_name}}
            @description={{htmlSafe setting.description}}
            @emphasis={{this.isOverridden setting}}
            @format={{this.fieldFormat setting.type}}
          >
            <:body as |field|>
              {{#if (eq setting.type "integer")}}
                <field.Input @type="number">
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Input>
              {{else if (eq setting.type "email")}}
                <field.Input>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Input>
              {{else if (eq setting.type "float")}}
                <field.Input @type="number">
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Input>
              {{else if (eq setting.type "string")}}
                <field.Input>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Input>
              {{else if (eq setting.type "upload")}}
                <field.Image @type="site_setting">
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Image>
              {{else if (eq setting.type "enum")}}
                <field.Select>
                  <:body as |select|>
                    {{#each setting.valid_values as |item|}}
                      <select.Option @value={{item.value}}>
                        {{item.name}}
                      </select.Option>
                    {{/each}}
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Select>
              {{else if (eq setting.type "category")}}
                <field.Custom>
                  <:body>
                    <CategoryChooser
                      @value={{readonly field.value}}
                      @onChangeCategory={{fn this.setCategory field.set}}
                      @options={{hash
                        allowUncategorized=true
                        none=(eq @setting.default "")
                      }}
                    />
                  </:body>

                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "group")}}
                <field.Custom>
                  <:body>
                    <GroupList @onChange={{field.set}} @value={{field.value}} />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "category_list")}}
                <field.Custom>
                  <:body>
                    <CategoryList
                      @changeValueCallback={{field.set}}
                      @value={{field.value}}
                    />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "tag_list")}}
                <field.Custom>
                  <:body>
                    <TagList @onChange={{field.set}} @value={{field.value}} />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "username")}}
                <field.Custom>
                  <:body>
                    <UserChooser
                      @value={{this.getUsernameArray field.value}}
                      @options={{hash maximum=1}}
                      @onChange={{fn this.setUsername field.set}}
                    />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "locale_enum")}}
                <field.Custom>
                  <:body>
                    <LocaleEnum
                      @setting={{setting}}
                      @changeValueCallback={{field.set}}
                      @value={{field.value}}
                    />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "host_list")}}
                <field.Custom>
                  <:body>
                    <HostList
                      @setting={{setting}}
                      @onChangeCallback={{field.set}}
                      @value={{field.value}}
                      @allowAny={{not (eq setting.anyValue false)}}
                    />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "group_list")}}
                <field.Custom>
                  <:body>
                    <GroupList @onChange={{field.set}} @value={{field.value}} />
                  </:body>
                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else if (eq setting.type "list")}}
                <field.Custom>
                  <:body>
                    {{#if (eq setting.list_type "font")}}
                      <FontList
                        @setting={{setting}}
                        @value={{field.value}}
                        @changeValueCallback={{field.set}}
                      />
                    {{else}}
                      <ValueList
                        @values={{field.value}}
                        @onChange={{fn this.setValueList field.set "|"}}
                        @inputDelimiter="|"
                        @choices={{setting.choices}}
                      />
                    {{/if}}
                  </:body>

                  <:primary-actions as |actions|>
                    <PrimaryActions
                      @form={{form}}
                      @field={{field}}
                      @actions={{actions}}
                      @setting={{setting}}
                      @save={{this.save}}
                    />
                  </:primary-actions>
                </field.Custom>
              {{else}}
                {{setting.type}}
              {{/if}}
            </:body>
          </form.Field>
        {{/if}}

      {{/each}}

      {{#if form.dirtyCount}}
        <form.Actions
          class="site-settings-form__floating-actions admin-changes-banner"
          @floating={{true}}
          @floatContainerClass="admin-detail"
        >
          <div class="admin-changes-banner__message">
            {{htmlSafe
              (i18n "admin.site_settings.dirty_banner" count=form.dirtyCount)
            }}
          </div>
          <div class="site-settings-form__floating-buttons">
            <form.Reset
              @translatedLabel={{i18n
                "admin.site_settings.discard"
                count=form.dirtyCount
              }}
            />
            <form.Submit
              @translatedLabel={{i18n
                "admin.site_settings.save"
                count=form.dirtyCount
              }}
            />
          </div>
        </form.Actions>

      {{/if}}
    </Form>
  </template>
}

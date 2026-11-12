import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import CategoryList from "discourse/admin/components/site-settings/category-list";
import Color from "discourse/admin/components/site-settings/color";
import FontList from "discourse/admin/components/site-settings/font-list";
import GroupList from "discourse/admin/components/site-settings/group-list";
import HostList from "discourse/admin/components/site-settings/host-list";
import LocaleEnum from "discourse/admin/components/site-settings/locale-enum";
import TagList from "discourse/admin/components/site-settings/tag-list";
import ValueList from "discourse/admin/components/value-list";
import SiteSetting from "discourse/admin/models/site-setting";
import Form from "discourse/components/form";
import { clipboardCopy } from "discourse/lib/utilities";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DFloatingControlBar from "discourse/ui-kit/d-floating-control-bar";
import { i18n } from "discourse-i18n";

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
      @class="btn-flat"
      @icon="gear"
      @identifier={{concat "site-setting-menu-" @setting.setting}}
    >
      <:content as |menu|>
        <menu.Dropdown as |dropdown|>
          <dropdown.item>
            <DButton
              @action={{fn this.revertToDefault menu}}
              @disabled={{this.cannotRevert}}
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
  @tracked floatingBarWidthSource = null;

  formApi = null;

  // The form is narrower than the column the bar should span; its container
  // shares the form's left edge, so matching it keeps the bar inside the column
  trackWidthSource = modifier((element) => {
    this.floatingBarWidthSource = element.parentElement;
  });

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

  @action
  async discard() {
    await this.formApi?.reset();
  }

  @action
  validateHexColor(name, color, helper) {
    // Allow empty values (for reset or optional colors)
    if (!color || color === "") {
      return;
    }

    const isValid = /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(color);
    if (!isValid) {
      const setting = this.args.settings.find((s) => s.setting === name);
      helper.addError(name, {
        title: setting?.label || setting?.humanized_name || name,
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

  // Checkboxes render the description inline as the control's label
  @action
  fieldDescription(setting) {
    if (setting.type !== "bool") {
      return trustHTML(setting.description);
    }
  }

  @action
  controlType(settingType) {
    switch (settingType) {
      case "bool":
        return "checkbox";
      case "integer":
      case "float":
      case "email":
      case "string":
        return "input";
      case "upload":
        return "image";
      case "enum":
        return "select";
      default:
        return "custom";
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
      class="form-kit-settings-wrapper"
      @data={{this.formData}}
      @onRegisterApi={{this.onRegisterApi}}
      @onSubmit={{this.save}}
      {{this.trackWidthSource}}
      as |form|
    >
      {{#each @settings as |setting|}}
        <form.Field
          @description={{this.fieldDescription setting}}
          @emphasis={{this.isOverridden setting}}
          @format={{this.fieldFormat setting.type}}
          @name={{setting.setting}}
          @title={{or setting.label setting.humanized_name setting.setting}}
          @type={{this.controlType setting.type}}
          @validate={{if (eq setting.type "color") this.validateHexColor}}
        >
          <:body as |field|>
            {{#if (eq setting.type "bool")}}
              <field.Control>{{trustHTML setting.description}}</field.Control>
            {{else if (eq setting.type "color")}}
              <field.Control>
                <Color
                  @changeValueCallback={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "integer")}}
              <field.Control @type="number" />
            {{else if (eq setting.type "float")}}
              <field.Control @type="number" />
            {{else if (eq setting.type "email")}}
              <field.Control @type="email" />
            {{else if (eq setting.type "string")}}
              <field.Control />
            {{else if (eq setting.type "upload")}}
              <field.Control @type="site_setting" />
            {{else if (eq setting.type "enum")}}
              <field.Control as |select|>
                {{#each setting.valid_values as |item|}}
                  <select.Option @value={{item.value}}>
                    {{item.name}}
                  </select.Option>
                {{/each}}
              </field.Control>
            {{else if (eq setting.type "category")}}
              <field.Control>
                <CategoryChooser
                  @onChangeCategory={{fn this.setCategory field.set}}
                  @options={{hash
                    allowUncategorized=true
                    none=(eq setting.default "")
                  }}
                  @value={{readonly field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "group")}}
              <field.Control>
                <GroupList
                  @changeValueCallback={{field.set}}
                  @setting={{setting}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "category_list")}}
              <field.Control>
                <CategoryList
                  @changeValueCallback={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "tag_list")}}
              <field.Control>
                <TagList
                  @changeValueCallback={{field.set}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "username")}}
              <field.Control>
                <UserChooser
                  @onChange={{fn this.setUsername field.set}}
                  @options={{hash maximum=1}}
                  @value={{this.getUsernameArray field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "locale_enum")}}
              <field.Control>
                <LocaleEnum
                  @changeValueCallback={{field.set}}
                  @setting={{setting}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "host_list")}}
              <field.Control>
                <HostList
                  @allowAny={{not (eq setting.anyValue false)}}
                  @changeValueCallback={{field.set}}
                  @setting={{setting}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "group_list")}}
              <field.Control>
                <GroupList
                  @changeValueCallback={{field.set}}
                  @setting={{setting}}
                  @value={{field.value}}
                />
              </field.Control>
            {{else if (eq setting.type "list")}}
              <field.Control>
                {{#if (eq setting.list_type "font")}}
                  <FontList
                    @changeValueCallback={{field.set}}
                    @setting={{setting}}
                    @value={{field.value}}
                  />
                {{else}}
                  <ValueList
                    @choices={{setting.choices}}
                    @inputDelimiter="|"
                    @onChange={{fn this.setValueList field.set "|"}}
                    @values={{field.value}}
                  />
                {{/if}}
              </field.Control>
            {{else}}
              {{setting.type}}
            {{/if}}
          </:body>

          <:primary-actions as |actions field|>
            <PrimaryActions
              @actions={{actions}}
              @field={{field}}
              @setting={{setting}}
            />
          </:primary-actions>
        </form.Field>
      {{/each}}

      {{#if form.dirtyCount}}
        <DFloatingControlBar
          @discardLabel={{i18n
            "admin.site_settings.discard"
            count=form.dirtyCount
          }}
          @label={{trustHTML
            (i18n "admin.site_settings.dirty_banner" count=form.dirtyCount)
          }}
          @onDiscard={{this.discard}}
          @onSave={{form.submit}}
          @saveLabel={{i18n "admin.site_settings.save" count=form.dirtyCount}}
          @widthSource={{this.floatingBarWidthSource}}
        />
      {{/if}}
    </Form>
  </template>
}

import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import MultiSelect from "select-kit/components/multi-select";

export default class AdminFlagsForm extends Component {
  @service router;
  @service site;

  get isUpdate() {
    return this.args.flag;
  }

  @cached
  get formData() {
    if (this.isUpdate) {
      return {
        name: this.args.flag.name,
        description: this.args.flag.description,
        appliesTo: this.args.flag.applies_to,
        requireMessage: this.args.flag.require_message,
        enabled: this.args.flag.enabled,
        autoActionType: this.args.flag.auto_action_type,
      };
    } else {
      return {
        enabled: true,
        requireMessage: false,
        autoActionType: false,
      };
    }
  }

  get header() {
    return this.isUpdate
      ? "admin.config_areas.flags.form.edit_header"
      : "admin.config_areas.flags.form.add_header";
  }

  get appliesToValues() {
    return this.site.valid_flag_applies_to_types.map((type) => {
      return {
        name: I18n.t(
          `admin.config_areas.flags.form.${type
            .toLowerCase()
            .replace("::", "_")}`
        ),
        id: type,
      };
    });
  }

  validateAppliesTo(name, value, { addError }) {
    if (value && value.length === 0) {
      addError("appliesTo", {
        title: i18n("admin.config_areas.flags.form.applies_to"),
        message: i18n("admin.config_areas.flags.form.invalid_applies_to"),
      });
    }
  }

  @action
  save({
    name,
    description,
    appliesTo,
    requireMessage,
    enabled,
    autoActionType,
  }) {
    const createOrUpdate = this.isUpdate ? this.update : this.create;
    const data = {
      name,
      description,
      enabled,
      applies_to: appliesTo,
      require_message: requireMessage,
      auto_action_type: autoActionType,
    };
    createOrUpdate(data);
  }

  @bind
  async create(data) {
    try {
      const response = await ajax("/admin/config/flags", {
        type: "POST",
        data,
      });
      this.site.flagTypes.push(response.flag);
      this.router.transitionTo("adminConfig.flags");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @bind
  async update(data) {
    try {
      const response = await ajax(`/admin/config/flags/${this.args.flag.id}`, {
        type: "PUT",
        data,
      });

      this.args.flag.name = response.flag.name;
      this.args.flag.description = response.flag.description;
      this.args.flag.applies_to = response.flag.applies_to;
      this.args.flag.require_message = response.flag.require_message;
      this.args.flag.enabled = response.flag.enabled;
      this.args.flag.auto_action_type = response.flag.auto_action_type;
      this.router.transitionTo("adminConfig.flags");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <BackButton
      @route="adminConfig.flags"
      @label="admin.config_areas.flags.back"
    />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content admin-flag-form">
        <AdminConfigAreaCard @heading={{this.header}}>
          <:content>
            <Form @onSubmit={{this.save}} @data={{this.formData}} as |form|>
              <form.Field
                @name="name"
                @title={{i18n "admin.config_areas.flags.form.name"}}
                @validation="required|length:3,200"
                @format="large"
                as |field|
              >
                <field.Input />
              </form.Field>

              <form.Field
                @name="description"
                @title={{i18n "admin.config_areas.flags.form.description"}}
                @validation="required|length:3,1000"
                as |field|
              >
                <field.Textarea @height={{60}} />
              </form.Field>

              <form.Field
                @name="appliesTo"
                @title={{i18n "admin.config_areas.flags.form.applies_to"}}
                @validation="required"
                @validate={{this.validateAppliesTo}}
                as |field|
              >
                <field.Custom>
                  <MultiSelect
                    @id={{field.id}}
                    @value={{field.value}}
                    @onChange={{field.set}}
                    @content={{this.appliesToValues}}
                    @options={{hash allowAny=false}}
                    class="admin-flag-form__applies-to"
                  />
                </field.Custom>
              </form.Field>

              <form.CheckboxGroup as |checkboxGroup|>
                <checkboxGroup.Field
                  @name="requireMessage"
                  @title={{i18n
                    "admin.config_areas.flags.form.require_message"
                  }}
                  as |field|
                >
                  <field.Checkbox>
                    {{i18n
                      "admin.config_areas.flags.form.require_message_description"
                    }}
                  </field.Checkbox>
                </checkboxGroup.Field>

                <checkboxGroup.Field
                  @name="enabled"
                  @title={{i18n "admin.config_areas.flags.form.enabled"}}
                  as |field|
                >
                  <field.Checkbox />
                </checkboxGroup.Field>

                <checkboxGroup.Field
                  @name="autoActionType"
                  @title={{i18n
                    "admin.config_areas.flags.form.auto_action_type"
                  }}
                  as |field|
                >
                  <field.Checkbox />
                </checkboxGroup.Field>
              </form.CheckboxGroup>

              <form.Alert @icon="info-circle">
                {{i18n "admin.config_areas.flags.form.alert"}}
              </form.Alert>

              <form.Submit @label="admin.config_areas.flags.form.save" />
            </Form>
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}

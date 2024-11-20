import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { eq, or } from "truth-helpers";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ValueList from "admin/components/value-list";
import UserField from "admin/models/user-field";

export default class AdminUserFieldsForm extends Component {
  @service dialog;
  @service router;
  @service adminUserFields;
  @service adminCustomUserFields;

  @tracked
  editableDisabled = this.args.userField.requirement === "for_all_users";
  originalRequirement = this.args.userField.requirement;
  userField;

  get fieldTypes() {
    return UserField.fieldTypes();
  }

  @cached
  get formData() {
    return this.args.userField.getProperties(
      "field_type",
      "name",
      "description",
      "requirement",
      "editable",
      "show_on_profile",
      "show_on_user_card",
      "searchable",
      "options",
      ...this.adminCustomUserFields.additionalProperties
    );
  }

  @action
  setRequirement(value, { set }) {
    set("requirement", value);

    if (value === "for_all_users") {
      this.editableDisabled = true;
      set("editable", true);
    } else {
      this.editableDisabled = false;
    }
  }

  @action
  async save(data) {
    let confirm = true;

    if (
      data.requirement === "for_all_users" &&
      this.originalRequirement !== "for_all_users"
    ) {
      confirm = await this._confirmChanges();
    }

    if (!confirm) {
      return;
    }

    try {
      const isNew = this.args.userField.isNew;

      await this.args.userField.save(data);

      this.originalRequirement = data.requirement;

      if (isNew) {
        this.adminUserFields.userFields.pushObject(this.args.userField);
      }

      this.router.transitionTo("adminUserFields.index");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  cancel() {
    this.router.transitionTo("adminUserFields.index");
  }

  _focusName() {
    schedule("afterRender", () =>
      document.querySelector(".user-field-name")?.focus()
    );
  }

  async _confirmChanges() {
    return new Promise((resolve) => {
      this.dialog.yesNoConfirm({
        message: i18n("admin.user_fields.requirement.confirmation"),
        didCancel: () => resolve(false),
        didConfirm: () => resolve(true),
      });
    });
  }

  <template>
    <Form
      @data={{this.formData}}
      @onSubmit={{this.save}}
      {{didInsert this._focusName}}
      as |form transientData|
    >
      <form.Field
        @name="field_type"
        @title={{i18n "admin.user_fields.type"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Select as |select|>
          {{#each this.fieldTypes as |fieldType|}}
            <select.Option
              @value={{fieldType.id}}
            >{{fieldType.name}}</select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <form.Field
        @name="name"
        @title={{i18n "admin.user_fields.name"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Input class="user-field-name" maxlength="255" />
      </form.Field>

      <form.Field
        @name="description"
        @title={{i18n "admin.user_fields.description"}}
        @format="large"
        @validation="required"
        as |field|
      >
        <field.Input class="user-field-desc" maxlength="1000" />
      </form.Field>

      {{#if
        (or
          (eq transientData.field_type "dropdown")
          (eq transientData.field_type "multiselect")
        )
      }}
        <form.Field
          @name="options"
          @title={{i18n "admin.user_fields.options"}}
          @format="large"
          @validation="required"
          as |field|
        >
          <field.Custom>
            <ValueList
              @values={{transientData.options}}
              @inputType="array"
              @onChange={{field.set}}
            />
          </field.Custom>
        </form.Field>
      {{/if}}

      <form.Field
        @name="requirement"
        @title={{i18n "admin.user_fields.requirement.title"}}
        @validation="required"
        @onSet={{this.setRequirement}}
        @format="full"
        as |field|
      >
        <field.RadioGroup as |radioGroup|>
          <radioGroup.Radio @value="optional">
            {{i18n "admin.user_fields.requirement.optional.title"}}
          </radioGroup.Radio>
          <radioGroup.Radio @value="for_all_users" as |radio|>
            {{i18n "admin.user_fields.requirement.for_all_users.title"}}
            <radio.Description>{{i18n
                "admin.user_fields.requirement.for_all_users.description"
              }}</radio.Description>
          </radioGroup.Radio>
          <radioGroup.Radio @value="on_signup" as |radio|>
            {{i18n "admin.user_fields.requirement.on_signup.title"}}
            <radio.Description>{{i18n
                "admin.user_fields.requirement.on_signup.description"
              }}</radio.Description>
          </radioGroup.Radio>
        </field.RadioGroup>
      </form.Field>

      <form.CheckboxGroup
        class="user-field-preferences"
        @title={{i18n "admin.user_fields.preferences"}}
        as |group|
      >
        <group.Field
          @name="editable"
          @showTitle={{false}}
          @title={{i18n "admin.user_fields.editable.title"}}
          as |field|
        >
          <field.Checkbox disabled={{this.editableDisabled}} />
        </group.Field>
        <group.Field
          @name="show_on_profile"
          @showTitle={{false}}
          @title={{i18n "admin.user_fields.show_on_profile.title"}}
          as |field|
        >
          <field.Checkbox />
        </group.Field>
        <group.Field
          @name="show_on_user_card"
          @showTitle={{false}}
          @title={{i18n "admin.user_fields.show_on_user_card.title"}}
          as |field|
        >
          <field.Checkbox />
        </group.Field>
        <group.Field
          @name="searchable"
          @showTitle={{false}}
          @title={{i18n "admin.user_fields.searchable.title"}}
          as |field|
        >
          <field.Checkbox />
        </group.Field>
      </form.CheckboxGroup>

      <PluginOutlet
        @name="after-admin-user-fields"
        @outletArgs={{hash userField=@userField form=form}}
      />

      <form.Actions>
        <form.Submit
          class="save"
          @icon="check"
          @label="admin.user_fields.save"
        />
        <form.Button
          @action={{this.cancel}}
          @label="admin.user_fields.cancel"
        />
      </form.Actions>
    </Form>
  </template>
}

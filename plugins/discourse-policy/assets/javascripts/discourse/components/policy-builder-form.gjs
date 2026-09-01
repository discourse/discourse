import Component from "@glimmer/component";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";
import PolicyGroupInput from "./policy-group-input";
import PolicyReminderInput from "./policy-reminder-input";

export default class PolicyBuilderForm extends Component {
  @action
  validatePolicy(data, { addError, removeError }) {
    if (isBlank(data.groups)) {
      addError("groups", {
        title: i18n("discourse_policy.builder.groups.label"),
        message: i18n("discourse_policy.builder.errors.group"),
      });
    } else {
      removeError("groups");
    }

    if (isBlank(data.version)) {
      addError("version", {
        title: i18n("discourse_policy.builder.version.label"),
        message: i18n("discourse_policy.builder.errors.version"),
      });
    } else {
      removeError("version");
    }
  }

  <template>
    <Form
      @data={{@data}}
      @onRegisterApi={{@onRegisterApi}}
      @onSubmit={{@onSubmit}}
      @validate={{this.validatePolicy}}
      as |form data|
    >
      <form.Field
        class="groups"
        @format="large"
        @name="groups"
        @title={{i18n "discourse_policy.builder.groups.label"}}
        @tooltip={{i18n "discourse_policy.builder.groups.description"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <div class="policy-builder-form__groups">
            <PolicyGroupInput
              @groups={{data.groups}}
              @onChangeGroup={{field.set}}
            />
          </div>
        </field.Control>
      </form.Field>

      <form.Field
        @format="small"
        @name="version"
        @title={{i18n "discourse_policy.builder.version.label"}}
        @tooltip={{i18n "discourse_policy.builder.version.description"}}
        @type="input-number"
        @validation="required"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="small"
        @name="renew"
        @title={{i18n "discourse_policy.builder.renew.label"}}
        @tooltip={{i18n "discourse_policy.builder.renew.description"}}
        @type="input-number"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="renewStart"
        @title={{i18n "discourse_policy.builder.renew-start.label"}}
        @tooltip={{i18n "discourse_policy.builder.renew-start.description"}}
        @type="input-date"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="reminder"
        @title={{i18n "discourse_policy.builder.reminder.label"}}
        @tooltip={{i18n "discourse_policy.builder.reminder.description"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <PolicyReminderInput
            @onChangeReminder={{field.set}}
            @reminder={{data.reminder}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @format="large"
        @name="accept"
        @title={{i18n "discourse_policy.builder.accept.label"}}
        @tooltip={{i18n "discourse_policy.builder.accept.description"}}
        @type="input-text"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="revoke"
        @title={{i18n "discourse_policy.builder.revoke.label"}}
        @tooltip={{i18n "discourse_policy.builder.revoke.description"}}
        @type="input-text"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        class="add-users-to-group"
        @format="large"
        @name="addUsersToGroup"
        @title={{i18n "discourse_policy.builder.add-users-to-group.label"}}
        @tooltip={{i18n
          "discourse_policy.builder.add-users-to-group.description"
        }}
        @type="custom"
        as |field|
      >
        <field.Control>
          <div class="policy-builder-form__add-users-to-group">
            <PolicyGroupInput
              @excludeAutomaticGroups={{true}}
              @groups={{data.addUsersToGroup}}
              @onChangeGroup={{field.set}}
            />
          </div>
        </field.Control>
      </form.Field>

      <form.Field
        @name="private"
        @title={{i18n "discourse_policy.builder.private.label"}}
        @tooltip={{i18n "discourse_policy.builder.private.description"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </form.Field>
    </Form>
  </template>
}

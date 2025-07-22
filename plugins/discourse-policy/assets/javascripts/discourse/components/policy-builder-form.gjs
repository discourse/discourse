import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import PolicyFormField from "./policy-form-field";
import PolicyGroupInput from "./policy-group-input";
import PolicyReminderInput from "./policy-reminder-input";

export default class PolicyBuilderForm extends Component {
  @action
  changeValue(field, event) {
    this.args.onChange(field, event.target.value);
  }

  @action
  changeBoolValue(field, event) {
    this.args.onChange(field, event.target.checked);
  }

  <template>
    <PolicyFormField @name="groups" @required={{true}}>
      <PolicyGroupInput
        @groups={{@policy.groups}}
        @onChangeGroup={{fn @onChange "groups"}}
      />
    </PolicyFormField>

    <PolicyFormField @name="version" @required={{true}}>
      <input
        name="version"
        type="number"
        value={{readonly @policy.version}}
        {{on "input" (fn this.changeValue "version")}}
      />
    </PolicyFormField>

    <PolicyFormField @name="renew">
      <input
        name="renew"
        type="number"
        value={{readonly @policy.renew}}
        {{on "input" (fn this.changeValue "renew")}}
      />
    </PolicyFormField>

    <PolicyFormField @name="renew-start">
      <input
        type="date"
        placeholder="2020-03-31"
        name="renew-start"
        value={{readonly (get @policy "renew-start")}}
        {{on "input" (fn this.changeValue "renew-start")}}
      />
    </PolicyFormField>

    <PolicyFormField @name="reminder">
      <PolicyReminderInput
        @reminder={{@policy.reminder}}
        @onChangeReminder={{fn @onChange "reminder"}}
      />
    </PolicyFormField>

    <PolicyFormField @name="accept">
      <input
        type="text"
        name="accept"
        value={{readonly @policy.accept}}
        {{on "input" (fn this.changeValue "accept")}}
      />
    </PolicyFormField>

    <PolicyFormField @name="revoke">
      <input
        type="text"
        name="revoke"
        value={{readonly @policy.revoke}}
        {{on "input" (fn this.changeValue "revoke")}}
      />
    </PolicyFormField>

    <PolicyFormField @name="add-users-to-group">
      <PolicyGroupInput
        @groups={{get @policy "add-users-to-group"}}
        @onChangeGroup={{fn @onChange "add-users-to-group"}}
      />
    </PolicyFormField>

    <PolicyFormField @name="private">
      <input
        type="checkbox"
        name="private"
        checked={{readonly @policy.private}}
        {{on "click" (fn this.changeBoolValue "private")}}
      />
    </PolicyFormField>
  </template>
}

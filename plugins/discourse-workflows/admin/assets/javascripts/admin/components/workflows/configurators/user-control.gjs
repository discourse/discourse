import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import UserChooser from "discourse/select-kit/components/user-chooser";
import ExpressionWrapper from "./expression-wrapper";

function usernamesFromValue(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (typeof value === "string" && value.length > 0) {
    return [value];
  }

  return [];
}

export default class UserControl extends Component {
  get multiple() {
    return Boolean(this.args.schema?.ui?.multiple);
  }

  get value() {
    const usernames = usernamesFromValue(this.args.field.value);
    return this.multiple ? usernames : usernames[0] || null;
  }

  get maximum() {
    return this.multiple ? null : 1;
  }

  @action
  handleChange(usernames) {
    this.args.field.set(this.multiple ? usernames || [] : usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <UserChooser
        @value={{this.value}}
        @onChange={{this.handleChange}}
        @options={{hash maximum=this.maximum excludeCurrentUser=false}}
      />
    </ExpressionWrapper>
  </template>
}

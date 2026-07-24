import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class UserOrGroupControl extends Component {
  @action
  handleChange(usernames) {
    this.args.field.set(usernames[0] || "");
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
      <EmailGroupUserChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
        @options={{hash maximum=1 includeGroups=true excludeCurrentUser=false}}
      />
    </ExpressionWrapper>
  </template>
}

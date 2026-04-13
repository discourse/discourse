import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import UserChooser from "discourse/select-kit/components/user-chooser";
import ExpressionWrapper from "./expression-wrapper";

export default class UserControl extends Component {
  @action
  handleChange(usernames) {
    this.args.field.set(usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
    >
      <UserChooser
        @value={{if @field.value @field.value null}}
        @onChange={{this.handleChange}}
        @options={{hash maximum=1 excludeCurrentUser=false}}
      />
    </ExpressionWrapper>
  </template>
}

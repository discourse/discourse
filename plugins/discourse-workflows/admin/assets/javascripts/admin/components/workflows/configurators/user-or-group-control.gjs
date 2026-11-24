import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import ExpressionWrapper from "./expression-wrapper.gjs";

export default class UserOrGroupControl extends Component {
  @service siteSettings;

  @action
  handleChange(usernames) {
    this.args.field.set(usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectUser
          @clearable={{true}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @id={{@field.id}}
          @includeGroups="visible"
          @invalid={{if @field.error true false}}
          @onChange={{legacyPickOne this.handleChange}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{if @field.value @field.value null}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <EmailGroupUserChooser
          @onChange={{this.handleChange}}
          @options={{hash
            maximum=1
            includeGroups=true
            excludeCurrentUser=false
          }}
          @value={{if @field.value @field.value null}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}

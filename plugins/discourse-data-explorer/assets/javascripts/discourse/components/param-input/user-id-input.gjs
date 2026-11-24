import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";

export default class UserIdInput extends Component {
  @service siteSettings;

  <template>
    <@Control id={{@field.id}}>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectUser
          name={{@info.identifier}}
          @clearable={{true}}
          @describedBy={{@field.describedBy}}
          @invalid={{if @field.error true false}}
          @onChange={{legacyPickOne @field.set}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{@field.value}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <EmailGroupUserChooser
          name={{@info.identifier}}
          @onChange={{@field.set}}
          @options={{hash maximum=1}}
          @value={{@field.value}}
        />
      {{/if}}
    </@Control>
  </template>
}

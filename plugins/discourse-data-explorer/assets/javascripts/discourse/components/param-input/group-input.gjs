import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

export default class GroupInput extends Component {
  @service site;
  @service siteSettings;

  get allGroups() {
    return this.site.get("groups");
  }

  get single() {
    return this.args.info.type === "group_id";
  }

  get groupChooserOption() {
    return this.args.info.type === "group_id"
      ? {
          maximum: 1,
        }
      : {};
  }

  <template>
    <@Control id={{@field.id}}>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        {{#if this.single}}
          <DSelectGroup
            name={{@info.identifier}}
            @clearable={{true}}
            @describedBy={{@field.describedBy}}
            @emit="names"
            @invalid={{if @field.error true false}}
            @onChange={{legacyPickOne @field.set}}
            @texts={{hash ariaLabel=@field.title}}
            @value={{@field.value}}
          />
        {{else}}
          <DSelectGroup
            name={{@info.identifier}}
            @describedBy={{@field.describedBy}}
            @emit="names"
            @invalid={{if @field.error true false}}
            @multiple={{true}}
            @onChange={{@field.set}}
            @texts={{hash ariaLabel=@field.title}}
            @value={{@field.value}}
          />
        {{/if}}
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <GroupChooser
          name={{@info.identifier}}
          @content={{this.allGroups}}
          @labelProperty="name"
          @onChange={{@field.set}}
          @options={{this.groupChooserOption}}
          @value={{@field.value}}
          @valueProperty="name"
        />
      {{/if}}
    </@Control>
  </template>
}

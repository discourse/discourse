import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldTagList extends Component {
  @service siteSettings;

  get selectedTags() {
    return splitString(this.args.field.value, TOKEN_SEPARATOR);
  }

  @action
  onChange(tags) {
    this.args.field.set(tags.map((tag) => tag.name).join(TOKEN_SEPARATOR));
  }

  @action
  onNamesChange(names) {
    this.args.field.set(names.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectTag
          @allowCreate={{false}}
          @disabled={{@field.disabled}}
          @emit="names"
          @ignoreRestrictions={{true}}
          @maximum={{false}}
          @multiple={{true}}
          @onChange={{this.onNamesChange}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.selectedTags}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <TagChooser
          @everyTag={{true}}
          @onChange={{this.onChange}}
          @options={{hash allowAny=false disabled=@field.disabled}}
          @tags={{this.selectedTags}}
          @unlimitedTagCount={{true}}
        />
      {{/if}}
    </@field.Control>
  </template>
}

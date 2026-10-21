import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";

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

  <template>
    <@field.Control>
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DTagChooser
          @allowCreate={{false}}
          @disabled={{@field.disabled}}
          @everyTag={{true}}
          @onChange={{this.onChange}}
          @tags={{this.selectedTags}}
          @unlimitedTagCount={{true}}
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

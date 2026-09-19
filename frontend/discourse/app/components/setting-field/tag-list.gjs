import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { splitString } from "discourse/lib/utilities";
import TagChooser from "discourse/select-kit/components/tag-chooser";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldTagList extends Component {
  get selectedTags() {
    return splitString(this.args.field.value, TOKEN_SEPARATOR);
  }

  @action
  onChange(tags) {
    this.args.field.set(tags.map((tag) => tag.name).join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      <TagChooser
        @everyTag={{true}}
        @onChange={{this.onChange}}
        @options={{hash allowAny=false disabled=@field.disabled}}
        @tags={{this.selectedTags}}
        @unlimitedTagCount={{true}}
      />
    </@field.Control>
  </template>
}

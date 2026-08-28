import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { splitString } from "discourse/lib/utilities";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";

const TOKEN_SEPARATOR = "|";

export default class SettingFieldTagGroupList extends Component {
  get selectedTagGroups() {
    return splitString(this.args.field.value, TOKEN_SEPARATOR);
  }

  @action
  onChange(tagGroups) {
    this.args.field.set(tagGroups.join(TOKEN_SEPARATOR));
  }

  <template>
    <@field.Control>
      <TagGroupChooser
        @tagGroups={{this.selectedTagGroups}}
        @onChange={{this.onChange}}
        @options={{hash
          filterPlaceholder="category.required_tag_group.placeholder"
          disabled=@field.disabled
        }}
      />
    </@field.Control>
  </template>
}

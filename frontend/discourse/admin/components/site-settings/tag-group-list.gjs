import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";

export default class TagGroupList extends Component {
  get selectedTagGroups() {
    return this.args.value.split("|").filter(Boolean);
  }

  @action
  onTagGroupChange(tagGroups) {
    this.args.changeValueCallback(tagGroups.join("|"));
  }

  <template>
    <div ...attributes>
      <TagGroupChooser
        @onChange={{this.onTagGroupChange}}
        @options={{hash
          filterPlaceholder="category.required_tag_group.placeholder"
          disabled=@disabled
        }}
        @tagGroups={{this.selectedTagGroups}}
      />
    </div>
  </template>
}

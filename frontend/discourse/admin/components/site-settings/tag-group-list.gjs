/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import TagGroupChooser from "discourse/select-kit/components/tag-group-chooser";

export default class TagGroupList extends Component {
  @computed("value")
  get selectedTagGroups() {
    return this.value.split("|").filter(Boolean);
  }

  @action
  onTagGroupChange(tagGroups) {
    this.set("value", tagGroups.join("|"));
  }

  <template>
    <TagGroupChooser
      @tagGroups={{this.selectedTagGroups}}
      @onChange={{this.onTagGroupChange}}
      @options={{hash
        filterPlaceholder="category.required_tag_group.placeholder"
        disabled=@disabled
      }}
    />
  </template>
}

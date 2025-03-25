import Component from "@ember/component";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";

export default class TagGroupList extends Component {
  @discourseComputed("value")
  selectedTagGroups(value) {
    return value.split("|").filter(Boolean);
  }

  @action
  onTagGroupChange(tagGroups) {
    this.set("value", tagGroups.join("|"));
  }
}

<TagGroupChooser
  @tagGroups={{this.selectedTagGroups}}
  @onChange={{this.onTagGroupChange}}
  @options={{hash filterPlaceholder="category.required_tag_group.placeholder"}}
/>
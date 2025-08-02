import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import TagGroupChooser from "select-kit/components/tag-group-chooser";

export default class TagGroupList extends Component {
  @discourseComputed("value")
  selectedTagGroups(value) {
    return value.split("|").filter(Boolean);
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
      }}
    />
  </template>
}

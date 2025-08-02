import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import TagChooser from "select-kit/components/tag-chooser";

export default class TagList extends Component {
  @discourseComputed("value")
  selectedTags(value) {
    return value.split("|").filter(Boolean);
  }

  @action
  changeSelectedTags(tags) {
    this.set("value", tags.join("|"));
  }

  <template>
    <TagChooser
      @tags={{this.selectedTags}}
      @onChange={{this.changeSelectedTags}}
      @everyTag={{true}}
      @unlimitedTagCount={{true}}
      @options={{hash allowAny=false}}
    />
  </template>
}

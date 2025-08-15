/* eslint-disable ember/no-classic-components */
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
    tags = tags.join("|");

    if (this.onChange) {
      this.onChange(tags);
    } else {
      this.set("value", tags);
    }
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

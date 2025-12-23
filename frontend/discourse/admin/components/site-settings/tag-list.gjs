/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import TagChooser from "discourse/select-kit/components/tag-chooser";

export default class TagList extends Component {
  @computed("value")
  get selectedTags() {
    return this.value.split("|").filter(Boolean);
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
      @options={{hash allowAny=false disabled=@disabled}}
    />
  </template>
}

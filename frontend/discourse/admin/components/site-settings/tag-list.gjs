import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import TagChooser from "discourse/select-kit/components/tag-chooser";

export default class TagList extends Component {
  get selectedTags() {
    return this.args.value.split("|").filter(Boolean);
  }

  @action
  changeSelectedTags(tags) {
    this.args.changeValueCallback(tags.map((t) => t.name).join("|"));
  }

  <template>
    <div ...attributes>
      <TagChooser
        @everyTag={{true}}
        @onChange={{this.changeSelectedTags}}
        @options={{hash allowAny=false disabled=@disabled}}
        @tags={{this.selectedTags}}
        @unlimitedTagCount={{true}}
      />
    </div>
  </template>
}

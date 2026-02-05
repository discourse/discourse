/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import TagChooser from "discourse/select-kit/components/tag-chooser";

@tagName("")
export default class TagList extends Component {
  @discourseComputed("value")
  selectedTags(value) {
    return value.split("|").filter(Boolean);
  }

  @action
  changeSelectedTags(tags) {
    tags = tags.map((t) => t.name).join("|");

    if (this.onChange) {
      this.onChange(tags);
    } else {
      this.set("value", tags);
    }
  }

  <template>
    <div ...attributes>
      <TagChooser
        @tags={{this.selectedTags}}
        @onChange={{this.changeSelectedTags}}
        @everyTag={{true}}
        @unlimitedTagCount={{true}}
        @options={{hash allowAny=false disabled=@disabled}}
      />
    </div>
  </template>
}

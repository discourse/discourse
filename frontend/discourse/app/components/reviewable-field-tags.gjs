/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

@tagName("")
export default class ReviewableFieldTags extends Component {
  @action
  onChange(tags) {
    this.set("value", tags);

    this.valueChanged?.({
      target: {
        value: tags,
      },
    });
  }

  <template>
    <MiniTagChooser
      @value={{this.value}}
      @onChange={{this.onChange}}
      @options={{hash categoryId=this.tagCategoryId}}
    />
  </template>
}

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

export default class ReviewableFieldTags extends Component {
  // The reviewable is not updated until the edit is saved, so the picked tags are held
  // here rather than read back from `@value`.
  @tracked editedValue;

  get value() {
    return this.editedValue ?? this.args.value;
  }

  @action
  onChange(tags) {
    this.editedValue = tags;

    this.args.valueChanged?.({
      target: {
        value: tags,
      },
    });
  }

  <template>
    <MiniTagChooser
      @onChange={{this.onChange}}
      @options={{hash categoryId=@tagCategoryId}}
      @value={{this.value}}
    />
  </template>
}

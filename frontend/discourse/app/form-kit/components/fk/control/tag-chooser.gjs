import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import TagChooser from "discourse/select-kit/components/tag-chooser";

export default class FKControlTagChooser extends Component {
  static controlType = "tag-chooser";

  @action
  handleChange(tags) {
    this.args.field.set(tags);
  }

  <template>
    <TagChooser
      @tags={{@field.value}}
      @onChange={{this.handleChange}}
      @everyTag={{@everyTag}}
      @excludeSynonyms={{@excludeSynonyms}}
      @excludeHasSynonyms={{@excludeHasSynonyms}}
      @unlimitedTagCount={{@unlimitedTagCount}}
      @categoryId={{@categoryId}}
      @allowCreate={{@allowCreate}}
      @options={{hash
        disabled=@field.disabled
        filterPlaceholder=@filterPlaceholder
      }}
      class="form-kit__control-tag-chooser"
    />
  </template>
}

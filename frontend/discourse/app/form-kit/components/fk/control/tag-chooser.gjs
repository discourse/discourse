import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import TagChooser from "discourse/select-kit/components/tag-chooser";

export default class FKControlTagChooser extends FKBaseControl {
  static controlType = "tag-chooser";

  @action
  handleChange(tags) {
    this.args.field.set(tags);
  }

  <template>
    <TagChooser
      class="form-kit__control-tag-chooser"
      @allowCreate={{@allowCreate}}
      @blockedTags={{@blockedTags}}
      @categoryId={{@categoryId}}
      @everyTag={{@showAllTags}}
      @excludeHasSynonyms={{@excludeTagsWithSynonyms}}
      @excludeSynonyms={{@excludeSynonyms}}
      @onChange={{this.handleChange}}
      @options={{hash
        disabled=@field.disabled
        filterPlaceholder=@placeholder
        maximum=@maximum
        mobilePlacement=@mobilePlacement
        prioritizeRecentTags=@prioritizeRecentTags
      }}
      @tags={{@field.value}}
      @unlimitedTagCount={{@unlimited}}
    />
  </template>
}

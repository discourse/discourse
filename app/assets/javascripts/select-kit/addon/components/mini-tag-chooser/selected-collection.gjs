import Component from "@ember/component";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class SelectedCollection extends Component {
  @reads("collection.content.selectedTags.[]") selectedTags;

  @computed("selectedTags.[]", "selectKit.filter")
  get tags() {
    if (!this.selectedTags) {
      return [];
    }

    let tags = this.selectedTags;
    if (tags.length >= 20 && this.selectKit.filter) {
      tags = tags.filter((t) => t.includes(this.selectKit.filter));
    } else if (tags.length >= 20) {
      tags = tags.slice(0, 20);
    }

    return tags.map((selectedTag) => {
      return {
        value: selectedTag,
        classNames: "selected-tag",
      };
    });
  }
}

{{#if this.tags}}
  <div class="mini-tag-chooser-selected-collection selected-tags">
    {{#each this.tags as |tag|}}
      <DButton
        @translatedTitle={{tag.value}}
        @icon="xmark"
        @action={{fn (action this.selectKit.deselect) tag.value}}
        tabindex="0"
        class={{tag.classNames}}
      >
        {{discourse-tag tag.value noHref=true}}
      </DButton>
    {{/each}}
  </div>
{{/if}}
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseTag from "discourse/helpers/discourse-tag";

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

  <template>
    {{#if this.tags}}
      <div class="mini-tag-chooser-selected-collection selected-tags">
        {{#each this.tags as |tag|}}
          <DButton
            @translatedTitle={{tag.value}}
            @icon="xmark"
            @action={{fn this.selectKit.deselect tag.value}}
            tabindex="0"
            class={{tag.classNames}}
          >
            {{discourseTag tag.value noHref=true}}
          </DButton>
        {{/each}}
      </div>
    {{/if}}
  </template>
}

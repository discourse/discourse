import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import discourseTag from "discourse/helpers/discourse-tag";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";

@classNames("tag-row")
export default class TagRow extends SelectKitRowComponent {
  @computed("item")
  get isTag() {
    return this.item.id !== "no-tags" && this.item.id !== "all-tags";
  }

  <template>
    {{#if this.isTag}}
      {{discourseTag
        this.rowValue
        noHref=true
        description=this.item.description
        count=this.item.count
      }}
    {{else}}
      <span class="name">{{this.item.name}}</span>
    {{/if}}
  </template>
}

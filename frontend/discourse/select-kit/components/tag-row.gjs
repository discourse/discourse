import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";

@classNames("tag-row")
export default class TagRow extends SelectKitRowComponent {
  @computed("item")
  get isTag() {
    return this.item.id !== "no-tags" && this.item.id !== "all-tags";
  }

  <template>
    {{#if this.isTag}}
      {{dDiscourseTag
        this.rowName
        noHref=true
        description=this.item.description
        count=this.item.count
      }}
    {{else}}
      <span class="name">{{this.rowName}}</span>
    {{/if}}
  </template>
}

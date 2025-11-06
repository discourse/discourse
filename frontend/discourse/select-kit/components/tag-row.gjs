import { classNames } from "@ember-decorators/component";
import discourseTag from "discourse/helpers/discourse-tag";
import discourseComputed from "discourse/lib/decorators";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("tag-row")
export default class TagRow extends SelectKitRowComponent {
  @discourseComputed("item")
  isTag(item) {
    return item.id !== "no-tags" && item.id !== "all-tags";
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

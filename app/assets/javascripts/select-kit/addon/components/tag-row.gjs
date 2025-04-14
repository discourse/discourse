import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("tag-row")
export default class TagRow extends SelectKitRowComponent {
  @discourseComputed("item")
  isTag(item) {
    return item.id !== "no-tags" && item.id !== "all-tags";
  }
}

{{#if this.isTag}}
  {{discourse-tag
    this.rowValue
    noHref=true
    description=this.item.description
    count=this.item.count
  }}
{{else}}
  <span class="name">{{this.item.name}}</span>
{{/if}}
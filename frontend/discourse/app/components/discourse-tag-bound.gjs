/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import { originalTagName, tagUrl } from "discourse/lib/tag-identity";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

@tagName("")
export default class DiscourseTagBound extends Component {
  @computed("tagRecord.name", "tagRecord.original_name")
  get tagClass() {
    return "tag-" + originalTagName(this.tagRecord);
  }

  @computed("tagRecord.slug", "tagRecord.id", "tagRecord.name")
  get href() {
    return tagUrl(this.tagRecord);
  }

  <template>
    <a
      href={{this.href}}
      class={{dConcatClass "discourse-tag" this.style this.tagClass}}
      ...attributes
    >{{this.tagRecord.name}}</a>
  </template>
}

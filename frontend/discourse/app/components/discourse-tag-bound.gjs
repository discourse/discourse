/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import getURL from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

@tagName("")
export default class DiscourseTagBound extends Component {
  @computed("tagRecord.name")
  get tagClass() {
    return "tag-" + this.tagRecord?.name;
  }

  @computed("tagRecord.slug", "tagRecord.id")
  get href() {
    if (this.tagRecord?.id) {
      const slugForUrl = this.tagRecord?.slug || `${this.tagRecord?.id}-tag`;
      return getURL(`/tag/${slugForUrl}/${this.tagRecord?.id}`);
    }
    // fallback for tags without id
    return getURL("/tag/" + this.tagRecord.name);
  }

  <template>
    <a
      href={{this.href}}
      class={{dConcatClass "discourse-tag" this.style this.tagClass}}
      ...attributes
    >{{this.tagRecord.name}}</a>
  </template>
}

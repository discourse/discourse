/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import getURL from "discourse/lib/get-url";

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
      class={{concatClass "discourse-tag" this.style this.tagClass}}
      ...attributes
    >{{this.tagRecord.name}}</a>
  </template>
}

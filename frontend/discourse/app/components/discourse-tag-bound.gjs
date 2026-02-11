/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

@tagName("")
export default class DiscourseTagBound extends Component {
  @discourseComputed("tagRecord.name")
  tagClass(name) {
    return "tag-" + name;
  }

  @discourseComputed("tagRecord.slug", "tagRecord.id")
  href(slug, id) {
    if (id) {
      const slugForUrl = slug || `${id}-tag`;
      return getURL(`/tag/${slugForUrl}/${id}`);
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

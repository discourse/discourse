/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

@tagName("a")
@classNameBindings(":discourse-tag", "style", "tagClass")
@attributeBindings("href")
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

  <template>{{this.tagRecord.name}}</template>
}

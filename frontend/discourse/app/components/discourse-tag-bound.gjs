/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

@tagName("")
export default class DiscourseTagBound extends Component {
  @discourseComputed("tagRecord.id")
  tagClass(tagRecordId) {
    return "tag-" + tagRecordId;
  }

  @discourseComputed("tagRecord.id")
  href(tagRecordId) {
    return getURL("/tag/" + tagRecordId);
  }

  <template>
    <a
      href={{this.href}}
      class={{concatClass "discourse-tag" this.style this.tagClass}}
      ...attributes
    >{{this.tagRecord.id}}</a>
  </template>
}

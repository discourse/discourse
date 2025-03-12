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
  @discourseComputed("tagRecord.id")
  tagClass(tagRecordId) {
    return "tag-" + tagRecordId;
  }

  @discourseComputed("tagRecord.id")
  href(tagRecordId) {
    return getURL("/tag/" + tagRecordId);
  }
}

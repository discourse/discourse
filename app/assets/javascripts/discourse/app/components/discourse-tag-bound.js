import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";

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

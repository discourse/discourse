import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
  tagName,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";

@tagName("a")
@classNameBindings(
  ":tag-badge-wrapper",
  ":badge-wrapper",
  ":bullet",
  "tagClass"
)
@attributeBindings("href")
export default class TagDropLink extends Component {
  @discourseComputed("tagId", "category")
  href(tagId, category) {
    let path;

    if (category) {
      path = "/tags" + category.path + "/" + tagId;
    } else {
      path = "/tag/" + tagId;
    }

    return getURL(path);
  }

  @discourseComputed("tagId")
  tagClass(tagId) {
    return "tag-" + tagId;
  }

  click(e) {
    e.preventDefault();
    DiscourseURL.routeTo(this.href);
    return true;
  }
}

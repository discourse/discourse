import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { classNameBindings, tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("section")
@classNameBindings(
  ":category-boxes-with-topics",
  "anyLogos:with-logos:no-logos"
)
export default class CategoriesBoxesWithTopics extends Component {
  lockIcon = "lock";

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any((c) => {
      return !isEmpty(c.get("uploaded_logo.url"));
    });
  }
}

import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import { classNameBindings, tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("section")
@classNameBindings(
  ":category-boxes",
  "anyLogos:with-logos:no-logos",
  "hasSubcategories:with-subcategories"
)
export default class CategoriesBoxes extends Component {
  lockIcon = "lock";

  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any((c) => !isEmpty(c.get("uploaded_logo.url")));
  }

  @discourseComputed("categories.[].subcategories")
  hasSubcategories() {
    return this.categories.any((c) => !isEmpty(c.get("subcategories")));
  }
}

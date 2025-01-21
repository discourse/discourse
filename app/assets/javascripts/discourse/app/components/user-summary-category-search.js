import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class UserSummaryCategorySearch extends Component {
  @discourseComputed("user", "category")
  searchParams() {
    let query = `@${this.get("user.username")} #${this.get("category.slug")}`;
    if (this.searchOnlyFirstPosts) {
      query += " in:first";
    }
    return query;
  }
}

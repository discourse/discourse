import Component from "@ember/component";
import { and } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default class CategoryReadOnlyBanner extends Component {
  @and("category.read_only_banner", "readOnly", "user") shouldShow;

  @discourseComputed
  user() {
    return this.currentUser;
  }
}

import Component from "@ember/component";
import discourseComputed from "discourse/lib/decorators";

export default class ReviewableUser extends Component {
  @discourseComputed("reviewable.user_fields")
  userFields(fields) {
    return this.site.collectUserFields(fields);
  }
}

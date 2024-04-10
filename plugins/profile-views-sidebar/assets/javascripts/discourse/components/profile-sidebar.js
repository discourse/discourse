import Component from "@ember/component";
import { inject as service } from "@ember/service";

export default class ProfileSidebar extends Component {
  @service currentUser;

  get course() {
    return this.currentUser.custom_fields?.user_field_1;
  }

  get viewCount() {
    return this.currentUser?.profile_view_count || 0;
  }
}

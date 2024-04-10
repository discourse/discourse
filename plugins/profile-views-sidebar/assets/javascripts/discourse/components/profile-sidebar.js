import Component from "@ember/component";
import { inject as service } from "@ember/service";

export default class ProfileSidebar extends Component {
  @service currentUser;

  get course() {
    return this.currentUser.custom_fields?.[
      this.siteSettings.user_enrollment_field
    ];
  }

  get viewCount() {
    return this.currentUser?.profile_view_count || 0;
  }
}

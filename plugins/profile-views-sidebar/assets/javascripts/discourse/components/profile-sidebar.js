import Component from "@ember/component";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

export default class ProfileSidebar extends Component {
  @service currentUser;

  constructor() {
    super(...arguments);
    this.fetchProfileViews();
  }

  async fetchProfileViews() {
    const profileViews = await ajax("/u/profile-views.json");
    this.set("profileViews", profileViews);
  }

  get topCollege() {
    return this.currentUser?.custom_fields?.[
      this.siteSettings.college_top_preference_field
    ];
  }

  get viewCount() {
    return this.currentUser?.profile_view_count || 0;
  }

  @discourseComputed("profileViews")
  firstUser(profileViews) {
    return profileViews?.views?.[0];
  }

  @discourseComputed("profileViews")
  secondUser(profileViews) {
    return profileViews?.views?.[1];
  }
}

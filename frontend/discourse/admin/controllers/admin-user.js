import Controller from "@ember/controller";
import { service } from "@ember/service";

export default class AdminUserController extends Controller {
  @service userNavSidebarStateManager;

  // Arriving from someone's profile, the Users config page's own header and
  // tabs are not the trail the viewer followed, and the sidebar already offers
  // the way back.
  get arrivedFromProfile() {
    const { entryURL, enteredFromAdmin } = this.userNavSidebarStateManager;

    return !!entryURL && !enteredFromAdmin;
  }
}

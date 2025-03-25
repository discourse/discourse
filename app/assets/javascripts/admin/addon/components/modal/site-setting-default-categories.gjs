import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class SiteSettingDefaultCategories extends Component {
  @action
  updateExistingUsers() {
    this.args.model.setUpdateExistingUsers(true);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.setUpdateExistingUsers(false);
    this.args.closeModal();
  }
}

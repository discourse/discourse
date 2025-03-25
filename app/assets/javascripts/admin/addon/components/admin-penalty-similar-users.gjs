import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default class AdminPenaltySimilarUsers extends Component {
  @tracked isLoading;
  @tracked similarUsers = [];
  selectedUserIds = [];

  constructor() {
    super(...arguments);

    this.loadSimilarUsers();
  }

  get penaltyField() {
    const penaltyType = this.args.penaltyType;
    if (penaltyType === "suspend") {
      return "can_be_suspended";
    } else if (penaltyType === "silence") {
      return "can_be_silenced";
    }
  }

  async loadSimilarUsers() {
    this.isLoading = true;
    try {
      const data = await ajax(
        `/admin/users/${this.args.user.id}/similar-users.json`
      );
      this.similarUsers = data.users;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  selectUserId(userId, event) {
    if (event.target.checked) {
      this.selectedUserIds.push(userId);
    } else {
      this.selectedUserIds = this.selectedUserIds.filter((id) => id !== userId);
    }

    this.args.onUsersChanged(this.selectedUserIds);
  }
}

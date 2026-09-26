import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import ModalService from "discourse/services/modal";

export default class GroupIndex extends DiscourseRoute {
  @service(() => ModalService) modal;

  titleToken() {
    return i18n("groups.members.title");
  }

  model(params) {
    this._params = params;
    return this.modelFor("group");
  }

  setupController(controller, model) {
    controller.setProperties({
      model,
      filterInput: this._params.filter,
      showing: "members",
    });

    controller.reloadMembers(true);
  }

  @action
  showAddMembersModal() {
    this.modal.show(
      () => import("discourse/components/modal/group-add-members"),
      { model: this.modelFor("group") }
    );
  }

  @action
  showInviteModal() {
    const group = this.modelFor("group");
    showCreateInviteModal(this, {
      model: { groupIds: [group.id] },
    });
  }

  @action
  didTransition() {
    this.controllerFor("group.index").set("filterInput", this._params.filter);
    return true;
  }
}

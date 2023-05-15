import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import ModalUpdateExistingUsers from "discourse/mixins/modal-update-existing-users";

export default class SiteSettingUserTipsController extends Controller.extend(
  ModalFunctionality,
  ModalUpdateExistingUsers
) {}

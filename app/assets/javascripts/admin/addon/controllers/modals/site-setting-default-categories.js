import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import ModalUpdateExistingUsers from "discourse/mixins/modal-update-existing-users";

export default class SiteSettingDefaultCategoriesController extends Controller.extend(
  ModalFunctionality,
  ModalUpdateExistingUsers
) {}

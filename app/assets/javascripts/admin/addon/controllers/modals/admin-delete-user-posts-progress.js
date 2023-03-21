import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class AdminDeleteUserPostsProgressController extends Controller.extend(
  ModalFunctionality
) {
  deletedPercentage = 0;
}

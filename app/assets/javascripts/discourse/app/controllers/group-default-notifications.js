import Controller from "@ember/controller";
import Modal from "discourse/controllers/modal";
import ModalUpdateExistingUsers from "discourse/mixins/modal-update-existing-users";

export default Controller.extend(ModalFunctionality, ModalUpdateExistingUsers);

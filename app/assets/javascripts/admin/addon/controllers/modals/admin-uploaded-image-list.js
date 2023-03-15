import { observes, on } from "@ember-decorators/object";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class AdminUploadedImageListController extends Controller.extend(
  ModalFunctionality
) {
  @on("init")
  @observes("model.value")
  _setup() {
    const value = this.get("model.value");
    this.set("images", value && value.length ? value.split("|") : []);
  }

  @action
  remove(url, event) {
    event?.preventDefault();
    this.images.removeObject(url);
  }

  @action
  uploadDone({ url }) {
    this.images.addObject(url);
  }

  @action
  close() {
    this.save(this.images.join("|"));
    this.send("closeModal");
  }
}

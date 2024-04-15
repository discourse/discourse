import Controller from "@ember/controller";
import { action } from "@ember/object";
import { empty } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import ApiKeyUrlsModal from "../components/modal/api-key-urls";

export default class AdminApiKeysShowController extends Controller.extend(
  bufferedProperty("model")
) {
  @service router;
  @service modal;

  @empty("model.id") isNew;

  @action
  saveDescription() {
    const buffered = this.buffered;
    const attrs = buffered.getProperties("description");

    this.model
      .save(attrs)
      .then(() => {
        this.set("editingDescription", false);
        this.rollbackBuffer();
      })
      .catch(popupAjaxError);
  }

  @action
  cancel() {
    const id = this.get("userField.id");
    if (isEmpty(id)) {
      this.destroyAction(this.userField);
    } else {
      this.rollbackBuffer();
      this.set("editing", false);
    }
  }

  @action
  editDescription() {
    this.toggleProperty("editingDescription");
    if (!this.editingDescription) {
      this.rollbackBuffer();
    }
  }

  @action
  revokeKey(key) {
    key.revoke().catch(popupAjaxError);
  }

  @action
  deleteKey(key) {
    key
      .destroyRecord()
      .then(() => this.router.transitionTo("adminApiKeys.index"))
      .catch(popupAjaxError);
  }

  @action
  undoRevokeKey(key) {
    key.undoRevoke().catch(popupAjaxError);
  }

  @action
  showURLs(urls) {
    this.modal.show(ApiKeyUrlsModal, {
      model: {
        urls,
      },
    });
  }
}

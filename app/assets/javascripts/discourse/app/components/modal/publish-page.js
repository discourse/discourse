import { action, computed } from "@ember/object";
import { equal, not } from "@ember/object/computed";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const States = {
  initializing: "initializing",
  checking: "checking",
  valid: "valid",
  invalid: "invalid",
  saving: "saving",
  new: "new",
  existing: "existing",
  unpublishing: "unpublishing",
  unpublished: "unpublished",
};

const StateHelpers = {};
Object.keys(States).forEach((name) => {
  StateHelpers[name] = equal("state", name);
});

export default Controller.extend(ModalFunctionality, StateHelpers, {
  state: null,
  reason: null,
  publishedPage: null,
  disabled: not("valid"),

  showUrl: computed("state", function () {
    return (
      this.state === States.valid ||
      this.state === States.saving ||
      this.state === States.existing
    );
  }),

  showUnpublish: computed("state", function () {
    return this.state === States.existing || this.state === States.unpublishing;
  }),

  onShow() {
    this.set("state", States.initializing);

    this.store
      .find("published_page", this.model.id)
      .then((page) => {
        this.setProperties({ state: States.existing, publishedPage: page });
      })
      .catch(this.startNew);
  },

  @action
  startCheckSlug() {
    if (this.state === States.existing) {
      return;
    }

    this.set("state", States.checking);
  },

  @action
  checkSlug() {
    if (this.state === States.existing) {
      return;
    }
    return ajax("/pub/check-slug", {
      data: { slug: this.publishedPage.slug },
    }).then((result) => {
      if (result.valid_slug) {
        this.set("state", States.valid);
      } else {
        this.setProperties({ state: States.invalid, reason: result.reason });
      }
    });
  },

  @action
  unpublish() {
    this.set("state", States.unpublishing);
    return this.publishedPage
      .destroyRecord()
      .then(() => {
        this.set("state", States.unpublished);
        this.model.set("publishedPage", null);
      })
      .catch((result) => {
        this.set("state", States.existing);
        popupAjaxError(result);
      });
  },

  @action
  publish() {
    this.set("state", States.saving);

    return this.publishedPage
      .update(this.publishedPage.getProperties("slug", "public"))
      .then(() => {
        this.set("state", States.existing);
        this.model.set("publishedPage", this.publishedPage);
      })
      .catch((errResult) => {
        popupAjaxError(errResult);
        this.set("state", States.existing);
      });
  },

  @action
  startNew() {
    this.setProperties({
      state: States.new,
      publishedPage: this.store.createRecord(
        "published_page",
        this.model.getProperties("id", "slug", "public")
      ),
    });
    this.checkSlug();
  },

  @action
  onChangePublic(isPublic) {
    this.publishedPage.set("public", isPublic);

    if (this.showUnpublish) {
      this.publish();
    }
  },
});

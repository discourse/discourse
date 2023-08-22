import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import Component from "@glimmer/component";
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

export default class PublishPageModal extends Component {
  @service store;

  @tracked state = States.initializing;
  @tracked reason = null;
  @tracked publishedPage = null;

  constructor() {
    super(...arguments);
    this.store
      .find("published_page", this.args.model.id)
      .then((page) => {
        this.state = States.existing;
        this.publishedPage = page;
      })
      .catch(this.startNew);
  }

  get initializing() {
    return this.state === States.initializing;
  }

  get checking() {
    return this.state === States.checking;
  }

  get valid() {
    return this.state === States.valid;
  }

  get invalid() {
    return this.state === States.invalid;
  }

  get saving() {
    return this.state === States.saving;
  }

  get new() {
    return this.state === States.new;
  }

  get existing() {
    return this.state === States.existing;
  }

  get unpublishing() {
    return this.state === States.unpublishing;
  }

  get unpublished() {
    return this.state === States.unpublished;
  }

  get disabled() {
    return this.state !== States.valid;
  }

  get showUrl() {
    return (
      this.state === States.valid ||
      this.state === States.saving ||
      this.state === States.existing
    );
  }

  get showUnpublish() {
    return this.state === States.existing || this.state === States.unpublishing;
  }

  @action
  startCheckSlug() {
    if (this.state === States.existing) {
      return;
    }

    this.state = States.checking;
  }

  @action
  checkSlug() {
    if (this.state === States.existing) {
      return;
    }
    return ajax("/pub/check-slug", {
      data: { slug: this.publishedPage.slug },
    }).then((result) => {
      if (result.valid_slug) {
        this.state = States.valid;
      } else {
        this.state = States.invalid;
        this.reason = result.reason;
      }
    });
  }

  @action
  unpublish() {
    this.state = States.unpublishing;
    return this.publishedPage
      .destroyRecord()
      .then(() => {
        this.state = States.unpublished;
        this.args.model.set("publishedPage", null);
      })
      .catch((result) => {
        this.state = States.existing;
        popupAjaxError(result);
      });
  }

  @action
  publish() {
    this.state = States.saving;

    return this.publishedPage
      .update(this.publishedPage.getProperties("slug", "public"))
      .then(() => {
        this.state = States.existing;
        this.args.model.set("publishedPage", this.publishedPage);
      })
      .catch((errResult) => {
        popupAjaxError(errResult);
        this.state = States.existing;
      });
  }

  @action
  startNew() {
    this.state = States.new;
    this.publishedPage = this.store.createRecord(
      "published_page",
      this.args.model.getProperties("id", "slug", "public")
    );
    this.checkSlug();
  }

  @action
  onChangePublic(event) {
    this.publishedPage.set("public", event.target.checked);

    if (this.showUnpublish) {
      this.publish();
    }
  }
}

import { cached, tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminSiteTextEdit extends Controller {
  @service dialog;

  @tracked siteText;

  saved = false;
  queryParams = ["locale"];

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.siteText,
    });
  }

  @computed("buffered.value", "siteText.value")
  get saveDisabled() {
    return this.siteText.value === this.get("buffered.value"); // TODO (devxp) we need a buffered proxy that works with tracked properties
  }

  @computed("siteText.status")
  get isOutdated() {
    return this.siteText?.status === "outdated";
  }

  @action
  saveChanges() {
    const attrs = this.buffered.getProperties("value");
    attrs.locale = this.locale;

    this.siteText
      .save(attrs)
      .then(() => {
        this.buffered.applyChanges();
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  }

  @action
  revertChanges() {
    this.set("saved", false);

    this.dialog.yesNoConfirm({
      message: i18n("admin.site_text.revert_confirm"),
      didConfirm: () => {
        this.siteText
          .revert(this.locale)
          .then((props) => {
            const buffered = this.buffered;
            buffered.setProperties(props);
            this.buffered.applyChanges();
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  dismissOutdated() {
    this.siteText
      .dismissOutdated(this.locale)
      .then(() => {
        this.siteText.set("status", "up_to_date");
      })
      .catch(popupAjaxError);
  }

  get interpolationKeys() {
    return this.siteText.interpolation_keys.join(", ");
  }
}

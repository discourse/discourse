import Controller from "@ember/controller";
import I18n from "I18n";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default Controller.extend(bufferedProperty("siteText"), {
  dialog: service(),
  saved: false,
  queryParams: ["locale"],

  @discourseComputed("buffered.value")
  saveDisabled(value) {
    return this.siteText.value === value;
  },

  @action
  saveChanges() {
    const attrs = this.buffered.getProperties("value");
    attrs.locale = this.locale;

    this.siteText
      .save(attrs)
      .then(() => {
        this.commitBuffer();
        this.set("saved", true);
      })
      .catch(popupAjaxError);
  },

  @action
  revertChanges() {
    this.set("saved", false);

    this.dialog.yesNoConfirm({
      message: I18n.t("admin.site_text.revert_confirm"),
      didConfirm: () => {
        this.siteText
          .revert(this.locale)
          .then((props) => {
            const buffered = this.buffered;
            buffered.setProperties(props);
            this.commitBuffer();
          })
          .catch(popupAjaxError);
      },
    });
  },
});

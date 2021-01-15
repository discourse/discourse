import Controller from "@ember/controller";
import I18n from "I18n";
import bootbox from "bootbox";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import discourseComputed from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(bufferedProperty("siteText"), {
  saved: false,
  queryParams: ["locale"],

  @discourseComputed("buffered.value")
  saveDisabled(value) {
    return this.siteText.value === value;
  },

  actions: {
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

    revertChanges() {
      this.set("saved", false);

      bootbox.confirm(I18n.t("admin.site_text.revert_confirm"), (result) => {
        if (result) {
          this.siteText
            .revert(this.locale)
            .then((props) => {
              const buffered = this.buffered;
              buffered.setProperties(props);
              this.commitBuffer();
            })
            .catch(popupAjaxError);
        }
      });
    },
  },
});

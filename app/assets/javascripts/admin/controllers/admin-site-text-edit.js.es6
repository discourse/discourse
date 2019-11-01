import Controller from "@ember/controller";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(bufferedProperty("siteText"), {
  saved: false,

  @computed("buffered.value")
  saveDisabled(value) {
    return this.siteText.value === value;
  },

  actions: {
    saveChanges() {
      const buffered = this.buffered;
      this.siteText
        .save(buffered.getProperties("value"))
        .then(() => {
          this.commitBuffer();
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    },

    revertChanges() {
      this.set("saved", false);
      bootbox.confirm(I18n.t("admin.site_text.revert_confirm"), result => {
        if (result) {
          this.siteText
            .revert()
            .then(props => {
              const buffered = this.buffered;
              buffered.setProperties(props);
              this.commitBuffer();
            })
            .catch(popupAjaxError);
        }
      });
    }
  }
});

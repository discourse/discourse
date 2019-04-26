import { popupAjaxError } from "discourse/lib/ajax-error";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(bufferedProperty("emailTemplate"), {
  saved: false,

  @computed("buffered")
  hasMultipleSubjects(buffered) {
    if (buffered.getProperties("subject")["subject"]) {
      return false;
    } else {
      return buffered.getProperties("id")["id"];
    }
  },

  actions: {
    saveChanges() {
      this.set("saved", false);
      const buffered = this.get("buffered");
      this.get("emailTemplate")
        .save(buffered.getProperties("subject", "body"))
        .then(() => {
          this.set("saved", true);
        })
        .catch(popupAjaxError);
    },

    revertChanges() {
      this.set("saved", false);
      bootbox.confirm(
        I18n.t("admin.customize.email_templates.revert_confirm"),
        result => {
          if (result) {
            this.get("emailTemplate")
              .revert()
              .then(props => {
                const buffered = this.get("buffered");
                buffered.setProperties(props);
                this.commitBuffer();
              })
              .catch(popupAjaxError);
          }
        }
      );
    }
  }
});

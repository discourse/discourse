import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const EmailStyle = RestModel.extend({
  changed: false,

  setField(fieldName, value) {
    this.set(`${fieldName}`, value);
    this.set("changed", true);
  },

  saveChanges() {
    return ajax("/admin/customize/email_style.json", {
      type: "PUT",
      data: {
        html: this.html,
        css: this.css
      }
    }).then(result => {
      if (!result.errors) {
        this.set("changed", false);
      }
    });
  }
});

export default EmailStyle;

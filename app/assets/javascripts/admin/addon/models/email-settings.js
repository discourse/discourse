import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

const EmailSettings = EmberObject.extend({});

EmailSettings.reopenClass({
  find() {
    return ajax("/admin/email.json").then(function (settings) {
      return EmailSettings.create(settings);
    });
  },
});

export default EmailSettings;

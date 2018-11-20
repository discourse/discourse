import computed from "ember-addons/ember-computed-decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ensureJSON, plainJSON, prettyJSON } from "discourse/lib/formatter";

export default Ember.Component.extend({
  tagName: "li",
  expandDetails: null,

  @computed("model.status")
  statusColorClasses(status) {
    if (!status) return "";

    if (status >= 200 && status <= 299) {
      return "text-successful";
    } else {
      return "text-danger";
    }
  },

  @computed("model.created_at")
  createdAt(createdAt) {
    return moment(createdAt).format("YYYY-MM-DD HH:mm:ss");
  },

  @computed("model.duration")
  completion(duration) {
    const seconds = Math.floor(duration / 10.0) / 100.0;
    return I18n.t("admin.web_hooks.events.completed_in", { count: seconds });
  },

  actions: {
    redeliver() {
      return bootbox.confirm(
        I18n.t("admin.web_hooks.events.redeliver_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            ajax(
              `/admin/api/web_hooks/${this.get(
                "model.web_hook_id"
              )}/events/${this.get("model.id")}/redeliver`,
              { type: "POST" }
            )
              .then(json => {
                this.set("model", json.web_hook_event);
              })
              .catch(popupAjaxError);
          }
        }
      );
    },

    toggleRequest() {
      const expandDetailsKey = "request";

      if (this.get("expandDetails") !== expandDetailsKey) {
        let headers = _.extend(
          {
            "Request URL": this.get("model.request_url"),
            "Request method": "POST"
          },
          ensureJSON(this.get("model.headers"))
        );
        this.setProperties({
          headers: plainJSON(headers),
          body: prettyJSON(this.get("model.payload")),
          expandDetails: expandDetailsKey,
          bodyLabel: I18n.t("admin.web_hooks.events.payload")
        });
      } else {
        this.set("expandDetails", null);
      }
    },

    toggleResponse() {
      const expandDetailsKey = "response";

      if (this.get("expandDetails") !== expandDetailsKey) {
        this.setProperties({
          headers: plainJSON(this.get("model.response_headers")),
          body: this.get("model.response_body"),
          expandDetails: expandDetailsKey,
          bodyLabel: I18n.t("admin.web_hooks.events.body")
        });
      } else {
        this.set("expandDetails", null);
      }
    }
  }
});

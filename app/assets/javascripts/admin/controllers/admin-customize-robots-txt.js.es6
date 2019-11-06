import { not } from "@ember/object/computed";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import { propertyEqual } from "discourse/lib/computed";

export default Controller.extend(bufferedProperty("model"), {
  saved: false,
  isSaving: false,
  saveDisabled: propertyEqual("model.robots_txt", "buffered.robots_txt"),
  resetDisbaled: not("model.overridden"),

  actions: {
    save() {
      this.setProperties({
        isSaving: true,
        saved: false
      });

      ajax("robots.json", {
        method: "PUT",
        data: { robots_txt: this.buffered.get("robots_txt") }
      })
        .then(data => {
          this.commitBuffer();
          this.set("saved", true);
          this.set("model.overridden", data.overridden);
        })
        .finally(() => this.set("isSaving", false));
    },

    reset() {
      this.setProperties({
        isSaving: true,
        saved: false
      });
      ajax("robots.json", { method: "DELETE" })
        .then(data => {
          this.buffered.set("robots_txt", data.robots_txt);
          this.commitBuffer();
          this.set("saved", true);
          this.set("model.overridden", false);
        })
        .finally(() => this.set("isSaving", false));
    }
  }
});

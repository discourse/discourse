import { cached, tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { not } from "@ember/object/computed";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { ajax } from "discourse/lib/ajax";
import { propertyEqual } from "discourse/lib/computed";

export default class AdminCustomizeRobotsTxtController extends Controller {
  @tracked model;
  saved = false;
  isSaving = false;

  @propertyEqual("model.robots_txt", "buffered.robots_txt") saveDisabled;

  @not("model.overridden") resetDisabled;

  @cached
  @dependentKeyCompat
  get buffered() {
    return BufferedProxy.create({
      content: this.model,
    });
  }

  @action
  save() {
    this.setProperties({
      isSaving: true,
      saved: false,
    });

    ajax("robots.json", {
      type: "PUT",
      data: { robots_txt: this.buffered.get("robots_txt") },
    })
      .then((data) => {
        this.buffered.applyChanges();
        this.set("saved", true);
        this.set("model.overridden", data.overridden);
      })
      .finally(() => this.set("isSaving", false));
  }

  @action
  reset() {
    this.setProperties({
      isSaving: true,
      saved: false,
    });
    ajax("robots.json", { type: "DELETE" })
      .then((data) => {
        this.buffered.set("robots_txt", data.robots_txt);
        this.buffered.applyChanges();
        this.set("saved", true);
        this.set("model.overridden", false);
      })
      .finally(() => this.set("isSaving", false));
  }
}

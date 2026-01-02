import { cached, tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { empty } from "@ember/object/computed";
import BufferedProxy from "ember-buffered-proxy/proxy";
import { ajax } from "discourse/lib/ajax";
import { propertyEqual } from "discourse/lib/computed";

export default class AdminCustomizeLlmsTxtController extends Controller {
  @tracked model;
  saved = false;
  isSaving = false;

  @propertyEqual("model.llms_txt", "buffered.llms_txt") saveDisabled;

  @empty("buffered.llms_txt") resetDisabled;

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

    ajax("llms.json", {
      type: "PUT",
      data: { llms_txt: this.buffered.get("llms_txt") },
    })
      .then(() => {
        this.buffered.applyChanges();
        this.set("saved", true);
      })
      .finally(() => this.set("isSaving", false));
  }

  @action
  reset() {
    this.setProperties({
      isSaving: true,
      saved: false,
    });
    ajax("llms.json", { type: "DELETE" })
      .then((data) => {
        this.buffered.set("llms_txt", data.llms_txt);
        this.buffered.applyChanges();
        this.set("saved", true);
      })
      .finally(() => this.set("isSaving", false));
  }
}

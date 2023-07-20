import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { A } from "@ember/array";
import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";
import { observes } from "discourse-common/utils/decorators";

export default class AdminEditBadgeGroupingsController extends Controller.extend(
  ModalFunctionality
) {
  @service dialog;

  @observes("model")
  modelChanged() {
    const model = this.model;
    const copy = A();
    const store = this.store;

    if (model) {
      model.forEach((o) =>
        copy.pushObject(store.createRecord("badge-grouping", o))
      );
    }

    this.set("workingCopy", copy);
  }

  moveItem(item, delta) {
    const copy = this.workingCopy;
    const index = copy.indexOf(item);
    if (index + delta < 0 || index + delta >= copy.length) {
      return;
    }

    copy.removeAt(index);
    copy.insertAt(index + delta, item);
  }

  @action
  up(item) {
    this.moveItem(item, -1);
  }

  @action
  down(item) {
    this.moveItem(item, 1);
  }

  @action
  delete(item) {
    this.workingCopy.removeObject(item);
  }

  @action
  cancel() {
    this.setProperties({ model: null, workingCopy: null });
    this.send("closeModal");
  }

  @action
  edit(item) {
    item.set("editing", true);
  }

  @action
  save(item) {
    item.set("editing", false);
  }

  @action
  add() {
    const obj = this.store.createRecord("badge-grouping", {
      editing: true,
      name: I18n.t("admin.badges.badge_grouping"),
    });
    this.workingCopy.pushObject(obj);
  }

  @action
  saveAll() {
    let items = this.workingCopy;
    const groupIds = items.map((i) => i.get("id") || -1);
    const names = items.map((i) => i.get("name"));

    ajax("/admin/badges/badge_groupings", {
      data: { ids: groupIds, names },
      type: "POST",
    }).then(
      (data) => {
        items = this.model;
        items.clear();
        data.badge_groupings.forEach((g) => {
          items.pushObject(this.store.createRecord("badge-grouping", g));
        });
        this.setProperties({ model: null, workingCopy: null });
        this.send("closeModal");
      },
      () => this.dialog.alert(I18n.t("generic_error"))
    );
  }
}

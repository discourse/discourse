import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { A } from "@ember/array";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { next } from "@ember/runloop";

export default class EditBadgeGroupings extends Component {
  @service dialog;
  @service store;

  @tracked workingCopy = A();

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
  edit(item) {
    item.editing = true;
  }

  @action
  save(item) {
    item.editing = false;
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
  async saveAll() {
    let items = this.workingCopy;
    const groupIds = items.map((i) => i.id || -1);
    const names = items.map((i) => i.name);

    try {
      const data = await ajax("/admin/badges/badge_groupings", {
        data: { ids: groupIds, names },
        type: "POST",
      });

      items = this.args.model.badgeGroupings;
      // items.clear();
      data.badge_groupings.forEach((g) => {
        items.pushObject(this.store.createRecord("badge-grouping", g));
      });

      // this.args.model.clearBadgeGroupings();
      // this.workingCopy = null;
      this.dialog.alert(I18n.t("generic_success"));
    } catch (error) {
      this.dialog.alert(I18n.t("generic_error"));
    }
  }

  didReceiveArgs() {
    this.updateWorkingCopy();
  }

  updateWorkingCopy() {
    const copy = A();
    if (this.args.model.badgeGroupings) {
      this.args.model.badgeGroupings.forEach((o) =>
        copy.pushObject(this.store.createRecord("badge-grouping", o))
      );
    }

    this.workingCopy = copy;
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
}

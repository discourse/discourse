import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { A } from "@ember/array";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class EditBadgeGroupings extends Component {
  @service dialog;
  @service store;

  @tracked workingCopy = new TrackedArray();

  constructor() {
    super(...arguments);
    let copy = A();
    if (this.args.model.badgeGroupings) {
      this.args.model.badgeGroupings.forEach((o) =>
        copy.pushObject(this.store.createRecord("badge-grouping", o))
      );
    }
    this.workingCopy = copy;
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
  add() {
    const obj = this.store.createRecord("badge-grouping", {
      editing: true,
      name: i18n("admin.badges.badge_grouping"),
    });
    this.workingCopy.pushObject(obj);
  }

  @action
  async saveAll() {
    const groupIds = this.workingCopy.map((i) => i.id || -1);
    const names = this.workingCopy.map((i) => i.name);
    try {
      const data = await ajax("/admin/badges/badge_groupings", {
        data: { ids: groupIds, names },
        type: "POST",
      });
      this.workingCopy.clear();
      data.badge_groupings.forEach((badgeGroup) => {
        this.workingCopy.pushObject(
          this.store.createRecord("badge-grouping", {
            ...badgeGroup,
            editing: false,
          })
        );
      });
      this.args.model.updateGroupings(this.workingCopy);
      this.args.closeModal();
    } catch {
      this.dialog.alert(i18n("generic_error"));
    }
  }

  moveItem(item, delta) {
    const index = this.workingCopy.indexOf(item);
    if (index + delta < 0 || index + delta >= this.workingCopy.length) {
      return;
    }
    this.workingCopy.removeAt(index);
    this.workingCopy.insertAt(index + delta, item);
  }
}

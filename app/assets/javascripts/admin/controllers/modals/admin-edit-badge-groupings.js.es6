import { ajax } from "discourse/lib/ajax";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend(ModalFunctionality, {
  @observes("model")
  modelChanged() {
    const model = this.get("model");
    const copy = Ember.A();
    const store = this.store;

    if (model) {
      model.forEach(o =>
        copy.pushObject(store.createRecord("badge-grouping", o))
      );
    }

    this.set("workingCopy", copy);
  },

  moveItem(item, delta) {
    const copy = this.get("workingCopy");
    const index = copy.indexOf(item);
    if (index + delta < 0 || index + delta >= copy.length) {
      return;
    }

    copy.removeAt(index);
    copy.insertAt(index + delta, item);
  },

  actions: {
    up(item) {
      this.moveItem(item, -1);
    },
    down(item) {
      this.moveItem(item, 1);
    },
    delete(item) {
      this.get("workingCopy").removeObject(item);
    },
    cancel() {
      this.setProperties({ model: null, workingCopy: null });
      this.send("closeModal");
    },
    edit(item) {
      item.set("editing", true);
    },
    save(item) {
      item.set("editing", false);
    },
    add() {
      const obj = this.store.createRecord("badge-grouping", {
        editing: true,
        name: I18n.t("admin.badges.badge_grouping")
      });
      this.get("workingCopy").pushObject(obj);
    },
    saveAll() {
      let items = this.get("workingCopy");
      const groupIds = items.map(i => i.get("id") || -1);
      const names = items.map(i => i.get("name"));

      ajax("/admin/badges/badge_groupings", {
        data: { ids: groupIds, names },
        method: "POST"
      }).then(
        data => {
          items = this.get("model");
          items.clear();
          data.badge_groupings.forEach(g => {
            items.pushObject(this.store.createRecord("badge-grouping", g));
          });
          this.setProperties({ model: null, workingCopy: null });
          this.send("closeModal");
        },
        () => bootbox.alert(I18n.t("generic_error"))
      );
    }
  }
});

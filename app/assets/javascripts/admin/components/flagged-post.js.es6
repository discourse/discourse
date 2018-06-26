import showModal from "discourse/lib/show-modal";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  adminTools: Ember.inject.service(),
  expanded: false,
  tagName: "div",
  classNameBindings: [
    ":flagged-post",
    "flaggedPost.hidden:hidden-post",
    "flaggedPost.deleted"
  ],

  canAct: Ember.computed.alias("actableFilter"),

  @computed("filter")
  actableFilter(filter) {
    return filter === "active";
  },

  removeAfter(promise) {
    return promise.then(() => this.attrs.removePost());
  },

  _spawnModal(name, model, modalClass) {
    let controller = showModal(name, { model, admin: true, modalClass });
    controller.removeAfter = p => this.removeAfter(p);
  },

  actions: {
    removeAfter(promise) {
      return this.removeAfter(promise);
    },

    disagree() {
      this.removeAfter(this.get("flaggedPost").disagreeFlags());
    },

    defer() {
      this.removeAfter(this.get("flaggedPost").deferFlags());
    },

    expand() {
      this.get("flaggedPost")
        .expandHidden()
        .then(() => {
          this.set("expanded", true);
        });
    },

    showModerationHistory() {
      this.get("adminTools").showModerationHistory({
        filter: "post",
        post_id: this.get("flaggedPost.id")
      });
    }
  }
});

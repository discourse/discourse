import computed from "ember-addons/ember-computed-decorators";

const ACTIONS = ["delete", "edit", "none"];
export default Ember.Component.extend({
  postAction: null,
  postEdit: null,

  @computed
  penaltyActions() {
    return ACTIONS.map(id => {
      return { id, name: I18n.t(`admin.user.penalty_post_${id}`) };
    });
  },

  editing: Ember.computed.equal("postAction", "edit"),

  actions: {
    penaltyChanged() {
      let postAction = this.get("postAction");

      // If we switch to edit mode, jump to the edit textarea
      if (postAction === "edit") {
        Ember.run.scheduleOnce("afterRender", () => {
          let $elem = this.$();
          let body = $elem.closest(".modal-body");
          body.scrollTop(body.height());
          $elem.find(".post-editor").focus();
        });
      }
    }
  }
});

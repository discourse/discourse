import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import DiscourseURL from "discourse/lib/url";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend(ModalFunctionality, {
  topicController: Ember.inject.controller("topic"),

  saving: false,
  new_user: null,

  selectedPostsCount: Ember.computed.alias(
    "topicController.selectedPostsCount"
  ),
  selectedPostsUsername: Ember.computed.alias(
    "topicController.selectedPostsUsername"
  ),

  @computed("saving", "new_user")
  buttonDisabled(saving, newUser) {
    return saving || Ember.isEmpty(newUser);
  },

  @computed("saving")
  buttonTitle(saving) {
    return saving ? I18n.t("saving") : I18n.t("topic.change_owner.action");
  },

  onShow() {
    this.setProperties({
      saving: false,
      new_user: ""
    });
  },

  actions: {
    changeOwnershipOfPosts() {
      this.set("saving", true);

      const options = {
        post_ids: this.get("topicController.selectedPostIds"),
        username: this.new_user
      };

      Discourse.Topic.changeOwners(
        this.get("topicController.model.id"),
        options
      ).then(
        () => {
          this.send("closeModal");
          this.topicController.send("deselectAll");
          if (this.get("topicController.multiSelect")) {
            this.topicController.send("toggleMultiSelect");
          }
          Ember.run.next(() =>
            DiscourseURL.routeTo(this.get("topicController.model.url"))
          );
        },
        () => {
          this.flash(I18n.t("topic.change_owner.error"), "alert-error");
          this.set("saving", false);
        }
      );

      return false;
    }
  }
});

import { withPluginApi } from "discourse/lib/plugin-api";
import computed from "ember-addons/ember-computed-decorators";
import showModal from "discourse/lib/show-modal";

function initializePollUIBuilder(api) {
  api.modifyClass("controller:composer", {
    @computed(
      "siteSettings.poll_enabled",
      "siteSettings.poll_minimum_trust_level_to_create",
      "model.topic.pm_with_non_human_user"
    )
    canBuildPoll(pollEnabled, minimumTrustLevel, pmWithNonHumanUser) {
      return (
        pollEnabled &&
        (pmWithNonHumanUser ||
          (this.currentUser &&
            (this.currentUser.staff ||
              this.currentUser.trust_level >= minimumTrustLevel)))
      );
    },

    actions: {
      showPollBuilder() {
        showModal("poll-ui-builder").set(
          "toolbarEvent",
          this.get("toolbarEvent")
        );
      }
    }
  });

  api.addToolbarPopupMenuOptionsCallback(function() {
    return {
      action: "showPollBuilder",
      icon: "bar-chart-o",
      label: "poll.ui_builder.title",
      condition: "canBuildPoll"
    };
  });
}

export default {
  name: "add-poll-ui-builder",

  initialize() {
    withPluginApi("0.8.7", initializePollUIBuilder);
  }
};

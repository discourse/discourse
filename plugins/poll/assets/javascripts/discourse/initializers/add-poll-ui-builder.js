import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import PollUiBuilder from "../components/modal/poll-ui-builder";
import { getOwner } from "@ember/application";

function initializePollUIBuilder(api) {
  api.modifyClass("controller:composer", {
    pluginId: "discourse-poll-ui-builder",
    @discourseComputed(
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
        getOwner(this)
          .lookup("service:modal")
          .show(PollUiBuilder, {
            model: { toolbarEvent: this.toolbarEvent },
          });
      },
    },
  });

  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      action: "showPollBuilder",
      icon: "chart-bar",
      label: "poll.ui_builder.title",
      condition: "canBuildPoll",
    };
  });
}

export default {
  name: "add-poll-ui-builder",

  initialize() {
    withPluginApi("0.8.7", initializePollUIBuilder);
  },
};

import { withPluginApi } from 'discourse/lib/plugin-api';
import showModal from 'discourse/lib/show-modal';

function initializePollUIBuilder(api) {
  const ComposerController = api.container.lookup("controller:composer");

  ComposerController.reopen({
    actions: {
      showPollBuilder() {
        showModal("poll-ui-builder").set("toolbarEvent", this.get("toolbarEvent"));
      }
    }
  });

  api.addToolbarPopupMenuOptionsCallback(function() {
    return {
      action: 'showPollBuilder',
      icon: 'bar-chart-o',
      label: 'poll.ui_builder.title'
    };
  });
}

export default {
  name: "add-poll-ui-builder",

  initialize() {
    withPluginApi('0.1', initializePollUIBuilder);
  }
};

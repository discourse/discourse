import { withPluginApi } from 'discourse/lib/plugin-api';
import showModal from 'discourse/lib/show-modal';

function initializePollUIBuilder(api) {
  const siteSettings = api.container.lookup('site-settings:main');

  if (!siteSettings.poll_enabled && (api.getCurrentUser() && !api.getCurrentUser().staff)) return;

  const ComposerController = api.container.lookupFactory("controller:composer");
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
    withPluginApi('0.5', initializePollUIBuilder);
  }
};

import { withPluginApi } from 'discourse/lib/plugin-api';

function initializeDetails(api) {
  api.decorateCooked($elem => $("details", $elem).details());

  api.addToolbarPopupMenuOptionsCallback(() => {
    return {
      action: 'insertDetails',
      icon: 'caret-right',
      label: 'details.title'
    };
  });

  const ComposerController = api.container.lookup("controller:composer");

  ComposerController.reopen({
    actions: {
      insertDetails() {
        this.get("toolbarEvent").applySurround(
          "[details=",
          `]${I18n.t("composer.details_text")}[/details]`,
          "details_title")
        ;
      }
    }
  });
}

export default {
  name: "apply-details",

  initialize() {
    withPluginApi('0.1', initializeDetails);
  }
};

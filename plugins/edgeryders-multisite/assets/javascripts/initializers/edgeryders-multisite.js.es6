import { withPluginApi } from "discourse/lib/plugin-api";

function initializeEdgerydersMultisite(api) {

  // see app/assets/javascripts/discourse/lib/plugin-api
  // for the functions available via the api object

  api.decorateWidget('header-buttons:before', function (helper) {
    if (!api.getCurrentUser()) {
      return helper.attach('link', {
        href: 'https://communities.edgeryders.eu',
        rawLabel: 'Sign Up',
        className: "widget-button btn btn-primary btn-small sign-up-button btn-text"
      });
    }
  });

}

export default {
  name: "edgeryders-multisite",

  initialize() {
    withPluginApi("0.8.24", initializeEdgerydersMultisite);
  }
};

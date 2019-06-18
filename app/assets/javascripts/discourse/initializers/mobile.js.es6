import Mobile from "discourse/lib/mobile";
import { setResolverOption } from "discourse-common/resolver";
import { isAppWebview, postRNWebviewMessage } from "discourse/lib/utilities";

// Initializes the `Mobile` helper object.
export default {
  name: "mobile",
  after: "inject-objects",

  initialize(container) {
    Mobile.init();
    const site = container.lookup("site:main");

    site.set("mobileView", Mobile.mobileView);
    site.set("isMobileDevice", Mobile.isMobileDevice);

    setResolverOption("mobileView", Mobile.mobileView);

    if (isAppWebview()) {
      Ember.run.later(() => {
        postRNWebviewMessage(
          "headerBg",
          $(".d-header").css("background-color")
        );
      }, 500);
    }
  }
};

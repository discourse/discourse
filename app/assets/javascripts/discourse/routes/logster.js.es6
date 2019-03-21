import getURL from "discourse-common/lib/get-url";
import { getOwner } from "discourse-common/lib/get-owner";

export default Discourse.Route.extend({
  beforeModel(transition) {
    const router = getOwner(this).lookup("router:main");
    const currentURL = router.get("currentURL");
    transition.abort();

    // hack due to Ember bug https://github.com/emberjs/ember.js/issues/5210
    // aborting the transition should revert the address bar to the
    // previous route's url, otherwise we will end up with a broken
    // back button
    // workaround is to update the address bar ourselves
    router.location.setURL(router.url);
    window.location.href = getURL(currentURL);
  }
});

import { lookup } from "discourse/lib/service";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import TopicTrackingState, {
  startTracking,
} from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import MessageBusService from "discourse/services/message-bus";
import SiteSettingsService from "discourse/services/site-settings";

export default {
  after: "discourse-bootstrap",

  initialize(app) {
    const siteSettings = lookup(app.__container__, SiteSettingsService);

    const currentUser = User.current();

    // We can't use a 'real' service factory (i.e. services/current-user.js) because we need
    // to register a null value for anon
    app.register("service:current-user", currentUser, { instantiate: false });

    this.topicTrackingState = TopicTrackingState.create({
      messageBus: lookup(app.__container__, MessageBusService),
      siteSettings,
      currentUser,
    });

    app.register("service:topic-tracking-state", this.topicTrackingState, {
      instantiate: false,
    });

    const site = Site.current();
    app.register("service:site", site, { instantiate: false });

    const session = Session.current();
    app.register("service:session", session, { instantiate: false });

    startTracking(this.topicTrackingState);
  },

  teardown() {
    // Manually call `willDestroy` as this isn't an actual `Service`
    this.topicTrackingState.willDestroy();
  },
};

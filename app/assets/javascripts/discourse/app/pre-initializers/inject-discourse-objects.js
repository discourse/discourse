import TopicTrackingState, {
  startTracking,
} from "discourse/models/topic-tracking-state";
import PrivateMessageTopicTrackingState from "discourse/models/private-message-topic-tracking-state";
import DiscourseLocation from "discourse/lib/discourse-location";
import KeyValueStore from "discourse/lib/key-value-store";
import MessageBus from "message-bus-client";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import deprecated from "discourse-common/lib/deprecated";

const ALL_TARGETS = ["controller", "component", "route", "model", "adapter"];

export function registerObjects(app) {
  if (app.__registeredObjects__) {
    // don't run registrations twice.
    return;
  }
  app.__registeredObjects__ = true;

  // TODO: This should be included properly
  app.register("message-bus:main", MessageBus, { instantiate: false });

  const siteSettings = app.SiteSettings;
  app.register("site-settings:main", siteSettings, { instantiate: false });
}

export default {
  name: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize(container, app) {
    registerObjects(app);

    app.register("store:main", {
      create() {
        deprecated(`"store:main" is deprecated, use "service:store" instead`, {
          since: "2.8.0.beta8",
          dropFrom: "2.9.0.beta1",
        });

        return container.lookup("service:store");
      },
    });

    let siteSettings = container.lookup("site-settings:main");

    const currentUser = User.current();
    app.register("current-user:main", currentUser, { instantiate: false });
    app.currentUser = currentUser;

    const topicTrackingState = TopicTrackingState.create({
      messageBus: MessageBus,
      siteSettings,
      currentUser,
    });

    app.register("topic-tracking-state:main", topicTrackingState, {
      instantiate: false,
    });

    const pmTopicTrackingState = PrivateMessageTopicTrackingState.create({
      messageBus: MessageBus,
      currentUser,
    });

    app.register("pm-topic-tracking-state:main", pmTopicTrackingState, {
      instantiate: false,
    });

    const site = Site.current();
    app.register("site:main", site, { instantiate: false });

    const session = Session.current();
    app.register("session:main", session, { instantiate: false });

    app.register("location:discourse-location", DiscourseLocation);

    const keyValueStore = new KeyValueStore("discourse_");
    app.register("key-value-store:main", keyValueStore, { instantiate: false });

    app.register("search-service:main", {
      create() {
        deprecated(
          `"search-service:main" is deprecated, use "service:search" instead`,
          {
            since: "2.8.0.beta8",
            dropFrom: "2.9.0.beta1",
          }
        );

        return container.lookup("service:search");
      },
    });

    ALL_TARGETS.forEach((t) => {
      app.inject(t, "appEvents", "service:app-events");
      app.inject(t, "pmTopicTrackingState", "pm-topic-tracking-state:main");
      app.inject(t, "store", "service:store");
      app.inject(t, "site", "site:main");
      app.inject(t, "searchService", "service:search");
    });

    ALL_TARGETS.concat("service").forEach((t) => {
      app.inject(t, "session", "session:main");
      app.inject(t, "messageBus", "message-bus:main");
      app.inject(t, "siteSettings", "site-settings:main");
      app.inject(t, "topicTrackingState", "topic-tracking-state:main");
      app.inject(t, "keyValueStore", "key-value-store:main");
    });

    if (currentUser) {
      ["controller", "component", "route", "service"].forEach((t) => {
        app.inject(t, "currentUser", "current-user:main");
      });
    }

    startTracking(topicTrackingState);
  },
};

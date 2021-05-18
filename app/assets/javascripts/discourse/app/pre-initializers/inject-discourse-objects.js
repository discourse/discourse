import TopicTrackingState, {
  startTracking,
} from "discourse/models/topic-tracking-state";
import DiscourseLocation from "discourse/lib/discourse-location";
import KeyValueStore from "discourse/lib/key-value-store";
import MessageBus from "message-bus-client";
import ScreenTrack from "discourse/lib/screen-track";
import SearchService from "discourse/services/search";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import Store from "discourse/models/store";
import User from "discourse/models/user";

const ALL_TARGETS = ["controller", "component", "route", "model", "adapter"];

export function registerObjects(container, app) {
  if (app.__registeredObjects__) {
    // don't run registrations twice.
    return;
  }
  app.__registeredObjects__ = true;

  app.register("store:main", Store);
  app.register("service:store", Store);

  // backwards compatibility: remove when plugins have updated
  app.appEvents = container.lookup("service:app-events");

  // TODO: This should be included properly
  app.register("message-bus:main", MessageBus, { instantiate: false });

  const siteSettings = app.SiteSettings;
  app.register("site-settings:main", siteSettings, { instantiate: false });
}

export default {
  name: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize(container, app) {
    registerObjects(container, app);

    let siteSettings = container.lookup("site-settings:main");

    ALL_TARGETS.forEach((t) =>
      app.inject(t, "appEvents", "service:app-events")
    );

    const currentUser = User.current();
    app.register("current-user:main", currentUser, { instantiate: false });
    app.currentUser = currentUser;

    ALL_TARGETS.forEach((t) =>
      app.inject(t, "topicTrackingState", "topic-tracking-state:main")
    );

    const topicTrackingState = TopicTrackingState.create({
      messageBus: MessageBus,
      siteSettings,
      currentUser,
    });
    app.register("topic-tracking-state:main", topicTrackingState, {
      instantiate: false,
    });

    const site = Site.current();
    app.register("site:main", site, { instantiate: false });

    const session = Session.current();
    app.register("session:main", session, { instantiate: false });

    // TODO: Automatically register this service
    const screenTrack = new ScreenTrack(
      topicTrackingState,
      siteSettings,
      session,
      currentUser,
      app.appEvents
    );
    app.register("service:screen-track", screenTrack, { instantiate: false });

    app.register("location:discourse-location", DiscourseLocation);

    const keyValueStore = new KeyValueStore("discourse_");
    app.register("key-value-store:main", keyValueStore, { instantiate: false });
    app.register("search-service:main", SearchService);

    ALL_TARGETS.forEach((t) => app.inject(t, "store", "service:store"));

    ALL_TARGETS.concat("service").forEach((t) =>
      app.inject(t, "messageBus", "message-bus:main")
    );

    ALL_TARGETS.concat("service").forEach((t) =>
      app.inject(t, "siteSettings", "site-settings:main")
    );

    ALL_TARGETS.forEach((t) => app.inject(t, "site", "site:main"));

    ALL_TARGETS.forEach((t) =>
      app.inject(t, "searchService", "search-service:main")
    );

    ALL_TARGETS.forEach((t) => app.inject(t, "session", "session:main"));
    app.inject("service", "session", "session:main");

    if (currentUser) {
      ["component", "route", "controller", "service"].forEach((t) => {
        app.inject(t, "currentUser", "current-user:main");
      });
    }

    ALL_TARGETS.forEach((t) =>
      app.inject(t, "keyValueStore", "key-value-store:main")
    );

    startTracking(topicTrackingState);
  },
};

import Session from "discourse/models/session";
import KeyValueStore from "discourse/lib/key-value-store";
import AppEvents from "discourse/lib/app-events";
import Store from "discourse/models/store";
import DiscourseURL from "discourse/lib/url";
import DiscourseLocation from "discourse/lib/discourse-location";
import SearchService from "discourse/services/search";
import {
  startTracking,
  default as TopicTrackingState
} from "discourse/models/topic-tracking-state";
import ScreenTrack from "discourse/lib/screen-track";

const ALL_TARGETS = ["controller", "component", "route", "model", "adapter"];

export default {
  name: "inject-discourse-objects",

  initialize(container, app) {
    const appEvents = AppEvents.create();
    app.register("app-events:main", appEvents, { instantiate: false });
    ALL_TARGETS.forEach(t => app.inject(t, "appEvents", "app-events:main"));
    DiscourseURL.appEvents = appEvents;

    // backwards compatibility: remove when plugins have updated
    app.register("store:main", Store);

    app.register("service:store", Store);
    ALL_TARGETS.forEach(t => app.inject(t, "store", "service:store"));

    const messageBus = window.MessageBus;
    app.register("message-bus:main", messageBus, { instantiate: false });
    ALL_TARGETS.forEach(t => app.inject(t, "messageBus", "message-bus:main"));

    const currentUser = Discourse.User.current();
    app.register("current-user:main", currentUser, { instantiate: false });

    const topicTrackingState = TopicTrackingState.create({
      messageBus,
      currentUser
    });
    app.register("topic-tracking-state:main", topicTrackingState, {
      instantiate: false
    });
    ALL_TARGETS.forEach(t =>
      app.inject(t, "topicTrackingState", "topic-tracking-state:main")
    );

    const siteSettings = Discourse.SiteSettings;
    app.register("site-settings:main", siteSettings, { instantiate: false });
    ALL_TARGETS.forEach(t =>
      app.inject(t, "siteSettings", "site-settings:main")
    );

    const site = Discourse.Site.current();
    app.register("site:main", site, { instantiate: false });
    ALL_TARGETS.forEach(t => app.inject(t, "site", "site:main"));

    app.register("search-service:main", SearchService);
    ALL_TARGETS.forEach(t =>
      app.inject(t, "searchService", "search-service:main")
    );

    const session = Session.current();
    app.register("session:main", session, { instantiate: false });
    ALL_TARGETS.forEach(t => app.inject(t, "session", "session:main"));

    const screenTrack = new ScreenTrack(
      topicTrackingState,
      siteSettings,
      session,
      currentUser
    );

    app.register("screen-track:main", screenTrack, { instantiate: false });
    ["component", "route"].forEach(t =>
      app.inject(t, "screenTrack", "screen-track:main")
    );

    if (currentUser) {
      ["component", "route", "controller"].forEach(t => {
        app.inject(t, "currentUser", "current-user:main");
      });
    }

    app.register("location:discourse-location", DiscourseLocation);

    const keyValueStore = new KeyValueStore("discourse_");
    app.register("key-value-store:main", keyValueStore, { instantiate: false });
    ALL_TARGETS.forEach(t =>
      app.inject(t, "keyValueStore", "key-value-store:main")
    );

    startTracking(topicTrackingState);
  }
};

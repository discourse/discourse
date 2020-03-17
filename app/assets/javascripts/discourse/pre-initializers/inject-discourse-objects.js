import Session from "discourse/models/session";
import KeyValueStore from "discourse/lib/key-value-store";
import Store from "discourse/models/store";
import DiscourseLocation from "discourse/lib/discourse-location";
import Discourse from "discourse";
import SearchService from "discourse/services/search";
import TopicTrackingState, {
  startTracking
} from "discourse/models/topic-tracking-state";
import ScreenTrack from "discourse/lib/screen-track";
import Site from "discourse/models/site";
import User from "discourse/models/user";

const ALL_TARGETS = ["controller", "component", "route", "model", "adapter"];

export default {
  name: "inject-discourse-objects",

  initialize(container, app) {
    ALL_TARGETS.forEach(t => app.inject(t, "appEvents", "service:app-events"));

    // backwards compatibility: remove when plugins have updated
    app.register("store:main", Store);

    if (!app.hasRegistration("service:store")) {
      app.register("service:store", Store);
      ALL_TARGETS.forEach(t => app.inject(t, "store", "service:store"));
    }

    const messageBus = window.MessageBus;
    app.register("message-bus:main", messageBus, { instantiate: false });
    ALL_TARGETS.forEach(t => app.inject(t, "messageBus", "message-bus:main"));

    const currentUser = User.current();
    app.register("current-user:main", currentUser, { instantiate: false });
    Discourse.currentUser = currentUser;

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

    const site = Site.current();
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

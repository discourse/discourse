import TopicTrackingState, {
  startTracking,
} from "discourse/models/topic-tracking-state";
import DiscourseLocation from "discourse/lib/discourse-location";
import Session from "discourse/models/session";
import Site from "discourse/models/site";
import User from "discourse/models/user";

const ALL_TARGETS = ["controller", "component", "route", "model", "adapter"];

export function injectServiceIntoService({ app, property, specifier }) {
  // app.inject doesn't allow implicit injection of services into services.
  // However, we need to do it in order to convert our old service-like objects
  // into true services, without breaking existing implicit injections.
  // This hack will be removed when we remove implicit injections for the Ember 4.0 update.

  // Supplying a specific injection with the same property name prevents the infinite
  // which would be caused by injecting a service into itself
  app.register("discourse:null", null, { instantiate: false });
  app.inject(specifier, property, "discourse:null");

  // Bypass the validation in `app.inject` by adding directly to the array
  app.__registry__._typeInjections["service"].push({
    property,
    specifier,
  });
}

export default {
  name: "inject-discourse-objects",
  after: "discourse-bootstrap",

  initialize(container, app) {
    const siteSettings = container.lookup("service:site-settings");

    const currentUser = User.current();

    // We can't use a 'real' service factory (i.e. services/current-user.js) because we need
    // to register a null value for anon
    app.register("service:current-user", currentUser, { instantiate: false });

    const topicTrackingState = TopicTrackingState.create({
      messageBus: container.lookup("service:message-bus"),
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

    app.register("location:discourse-location", DiscourseLocation);

    ALL_TARGETS.forEach((t) => {
      app.inject(t, "appEvents", "service:app-events");
      app.inject(t, "pmTopicTrackingState", "service:pm-topic-tracking-state");
      app.inject(t, "store", "service:store");
      app.inject(t, "site", "site:main");
      app.inject(t, "searchService", "service:search");
      app.inject(t, "session", "session:main");
      app.inject(t, "messageBus", "service:message-bus");
      app.inject(t, "siteSettings", "service:site-settings");
      app.inject(t, "topicTrackingState", "topic-tracking-state:main");
      app.inject(t, "keyValueStore", "service:key-value-store");
    });

    app.inject("service", "session", "session:main");
    injectServiceIntoService({
      app,
      property: "messageBus",
      specifier: "service:message-bus",
    });
    injectServiceIntoService({
      app,
      property: "siteSettings",
      specifier: "service:site-settings",
    });
    app.inject("service", "topicTrackingState", "topic-tracking-state:main");
    injectServiceIntoService({
      app,
      property: "keyValueStore",
      specifier: "service:key-value-store",
    });

    if (currentUser) {
      ["controller", "component", "route"].forEach((t) => {
        app.inject(t, "currentUser", "service:current-user");
      });
      injectServiceIntoService({
        app,
        property: "currentUser",
        specifier: "service:current-user",
      });
    }

    startTracking(topicTrackingState);
  },
};

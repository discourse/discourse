import Session from 'discourse/models/session';
import KeyValueStore from 'discourse/lib/key-value-store';
import AppEvents from 'discourse/lib/app-events';
import Store from 'discourse/models/store';
import DiscourseURL from 'discourse/lib/url';
import DiscourseLocation from 'discourse/lib/discourse-location';
import SearchService from 'discourse/services/search';
import { startTracking, default as TopicTrackingState } from 'discourse/models/topic-tracking-state';

function inject() {
  const app = arguments[0],
        name = arguments[1],
        singletonName = Ember.String.underscore(name).replace(/_/g, '-') + ':main';

  Array.prototype.slice.call(arguments, 2).forEach(dest => app.inject(dest, name, singletonName));
}

function injectAll(app, name) {
  inject(app, name, 'controller', 'component', 'route', 'view', 'model', 'adapter');
}

export default {
  name: "inject-discourse-objects",

  initialize(container, app) {
    const appEvents = AppEvents.create();
    app.register('app-events:main', appEvents, { instantiate: false });
    injectAll(app, 'appEvents');
    DiscourseURL.appEvents = appEvents;

    app.register('store:main', Store);
    inject(app, 'store', 'route', 'controller');

    const messageBus = window.MessageBus;
    app.register('message-bus:main', messageBus, { instantiate: false });
    injectAll(app, 'messageBus');

    const currentUser = Discourse.User.current();
    app.register('current-user:main', currentUser, { instantiate: false });

    const tracking = TopicTrackingState.create({ messageBus, currentUser });
    app.register('topic-tracking-state:main', tracking, { instantiate: false });
    injectAll(app, 'topicTrackingState');

    const site = Discourse.Site.current();
    app.register('site:main', site, { instantiate: false });
    injectAll(app, 'site');

    app.register('site-settings:main', Discourse.SiteSettings, { instantiate: false });
    injectAll(app, 'siteSettings');

    app.register('search-service:main', SearchService);
    injectAll(app, 'searchService');

    app.register('session:main', Session.current(), { instantiate: false });
    injectAll(app, 'session');

    inject(app, 'currentUser', 'component', 'route', 'controller');

    app.register('location:discourse-location', DiscourseLocation);

    const keyValueStore = new KeyValueStore("discourse_");
    app.register('key-value-store:main', keyValueStore, { instantiate: false });
    injectAll(app, 'keyValueStore');

    startTracking(tracking);
  }
};

import Session from 'discourse/models/session';
import KeyValueStore from 'discourse/lib/key-value-store';
import AppEvents from 'discourse/lib/app-events';
import Store from 'discourse/models/store';
import DiscourseURL from 'discourse/lib/url';
import DiscourseLocation from 'discourse/lib/discourse-location';
import SearchService from 'discourse/services/search';
import { startTracking, default as TopicTrackingState } from 'discourse/models/topic-tracking-state';
import ScreenTrack from 'discourse/lib/screen-track';
import TopicFooterButtons from 'discourse/components/topic-footer-buttons';

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

    const topicTrackingState = TopicTrackingState.create({ messageBus, currentUser });
    app.register('topic-tracking-state:main', topicTrackingState, { instantiate: false });
    injectAll(app, 'topicTrackingState');

    const site = Discourse.Site.current();
    app.register('site:main', site, { instantiate: false });
    injectAll(app, 'site');

    const siteSettings = Discourse.SiteSettings;
    app.register('site-settings:main', siteSettings, { instantiate: false });
    injectAll(app, 'siteSettings');

    app.register('search-service:main', SearchService);
    injectAll(app, 'searchService');

    const session = Session.current();
    app.register('session:main', session, { instantiate: false });
    injectAll(app, 'session');

    const screenTrack = new ScreenTrack(topicTrackingState, siteSettings, session, currentUser);
    app.register('screen-track:main', screenTrack, { instantiate: false });
    inject(app, 'screenTrack', 'component', 'route');

    inject(app, 'currentUser', 'component', 'route', 'controller');

    app.register('location:discourse-location', DiscourseLocation);

    const keyValueStore = new KeyValueStore("discourse_");
    app.register('key-value-store:main', keyValueStore, { instantiate: false });
    injectAll(app, 'keyValueStore');

    Discourse.TopicFooterButtonsView = {
      reopen(obj) {
        Ember.warn('`Discourse.TopicFooterButtonsView` is deprecated. Use the `topic-footer-buttons` component instead');
        TopicFooterButtons.reopen(obj);
      }
    };

    startTracking(topicTrackingState);
  }
};

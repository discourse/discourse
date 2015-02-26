import Session from 'discourse/models/session';
import AppEvents from 'discourse/lib/app-events';
import Store from 'discourse/models/store';

export default {
  name: "inject-objects",
  initialize(container, app) {

    // Inject appEvents everywhere
    const appEvents = AppEvents.create();
    app.register('app-events:main', appEvents, { instantiate: false });

    app.inject('controller', 'appEvents', 'app-events:main');
    app.inject('component', 'appEvents', 'app-events:main');
    app.inject('route', 'appEvents', 'app-events:main');
    app.inject('view', 'appEvents', 'app-events:main');
    app.inject('model', 'appEvents', 'app-events:main');
    Discourse.URL.appEvents = appEvents;

    // Inject Discourse.Site to avoid using Discourse.Site.current()
    const site = Discourse.Site.current();
    app.register('site:main', site, { instantiate: false });
    app.inject('controller', 'site', 'site:main');
    app.inject('component', 'site', 'site:main');
    app.inject('route', 'site', 'site:main');
    app.inject('view', 'site', 'site:main');
    app.inject('model', 'site', 'site:main');

    // Inject Discourse.SiteSettings to avoid using Discourse.SiteSettings globals
    app.register('site-settings:main', Discourse.SiteSettings, { instantiate: false });
    app.inject('controller', 'siteSettings', 'site-settings:main');
    app.inject('component', 'siteSettings', 'site-settings:main');
    app.inject('route', 'siteSettings', 'site-settings:main');
    app.inject('view', 'siteSettings', 'site-settings:main');
    app.inject('model', 'siteSettings', 'site-settings:main');

    // Inject Session for transient data
    app.register('session:main', Session.current(), { instantiate: false });
    app.inject('controller', 'session', 'session:main');
    app.inject('component', 'session', 'session:main');
    app.inject('route', 'session', 'session:main');
    app.inject('view', 'session', 'session:main');
    app.inject('model', 'session', 'session:main');

    app.register('current-user:main', Discourse.User.current(), { instantiate: false });
    app.inject('component', 'currentUser', 'current-user:main');
    app.inject('route', 'currentUser', 'current-user:main');
    app.inject('controller', 'currentUser', 'current-user:main');

    app.register('store:main', Store);
    app.inject('route', 'store', 'store:main');
    app.inject('controller', 'store', 'store:main');
  }
};

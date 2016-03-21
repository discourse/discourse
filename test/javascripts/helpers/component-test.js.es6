import AppEvents from 'discourse/lib/app-events';
import createStore from 'helpers/create-store';
import { autoLoadModules } from 'discourse/initializers/auto-load-modules';

export default function(name, opts) {
  opts = opts || {};

  test(name, function(assert) {
    const appEvents = AppEvents.create();
    this.site = Discourse.Site.current();

    this.container.register('site-settings:main', Discourse.SiteSettings, { instantiate: false });
    this.container.register('app-events:main', appEvents, { instantiate: false });
    this.container.register('capabilities:main', Ember.Object);
    this.container.register('site:main', this.site, { instantiate: false });
    this.container.injection('component', 'siteSettings', 'site-settings:main');
    this.container.injection('component', 'appEvents', 'app-events:main');
    this.container.injection('component', 'capabilities', 'capabilities:main');
    this.container.injection('component', 'site', 'site:main');

    this.siteSettings = Discourse.SiteSettings;

    autoLoadModules();

    if (opts.setup) {
      const store = createStore();
      this.currentUser = Discourse.User.create();
      this.container.register('store:main', store, { instantiate: false });
      this.container.register('current-user:main', this.currentUser, { instantiate: false });
      opts.setup.call(this, store);
    }

    andThen(() => this.render(opts.template));
    andThen(() => opts.test.call(this, assert));
  });
}

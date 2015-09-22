import AppEvents from 'discourse/lib/app-events';
import createStore from 'helpers/create-store';

export default function(name, opts) {
  opts = opts || {};

  test(name, function(assert) {
    if (opts.setup) {
      const store = createStore();
      opts.setup.call(this, store);
    }
    const appEvents = AppEvents.create();

    this.container.register('site-settings:main', Discourse.SiteSettings, { instantiate: false });
    this.container.register('app-events:main', appEvents, { instantiate: false });
    this.container.register('capabilities:main', Ember.Object);
    this.container.injection('component', 'siteSettings', 'site-settings:main');
    this.container.injection('component', 'appEvents', 'app-events:main');
    this.container.injection('component', 'capabilities', 'capabilities:main');

    andThen(() => {
      this.render(opts.template);
    });

    andThen(() => {
      opts.test.call(this, assert);
    });
  });
}

import createStore from 'helpers/create-store';

export default function(name, opts) {
  opts = opts || {};

  test(name, function(assert) {
    if (opts.setup) {
      const store = createStore();
      opts.setup.call(this, store);
    }
    this.container.register('site-settings:main', Discourse.SiteSettings, { instantiate: false });
    this.container.injection('component', 'siteSettings', 'site-settings:main');

    andThen(() => {
      this.render(opts.template);
    });

    andThen(() => {
      opts.test.call(this, assert);
    });
  });
}

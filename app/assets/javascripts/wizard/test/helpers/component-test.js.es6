import initializer from "wizard/initializers/load-helpers";

export function componentTest(name, opts) {
  opts = opts || {};

  test(name, function(assert) {
    initializer.initialize(this.registry);

    if (opts.beforeEach) {
      opts.beforeEach.call(this);
    }

    andThen(() => this.render(opts.template));
    andThen(() => opts.test.call(this, assert));
  });
}

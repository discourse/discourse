import initializer from "wizard/initializers/load-helpers";

export function componentTest(name, opts) {
  opts = opts || {};

  test(name, async function(assert) {
    initializer.initialize(this.registry);

    if (opts.beforeEach) {
      opts.beforeEach.call(this);
    }

    await this.render(opts.template);
    await opts.test.call(this, assert);
  });
}

/* eslint-disable no-undef */
import initializer from "wizard/initializers/load-helpers";
import { test } from "qunit";

export function componentTest(name, opts) {
  opts = opts || {};

  test(name, function (assert) {
    initializer.initialize(this.registry);

    if (opts.beforeEach) {
      opts.beforeEach.call(this);
    }

    andThen(() => this.render(opts.template));
    andThen(() => opts.test.call(this, assert));
  });
}

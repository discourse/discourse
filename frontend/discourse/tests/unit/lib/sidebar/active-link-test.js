import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { findActiveLink } from "discourse/lib/sidebar/active-link";

module("Unit | Sidebar | active-link", function (hooks) {
  setupTest(hooks);

  function routerStub({ active = [], currentURL = "/" } = {}) {
    return {
      currentURL,
      isActive(route) {
        if (route === undefined) {
          throw new Error("no route");
        }
        return active.includes(route);
      },
    };
  }

  test("returns undefined when there are no links", function (assert) {
    assert.strictEqual(findActiveLink([], routerStub()), undefined);
    assert.strictEqual(findActiveLink(undefined, routerStub()), undefined);
  });

  test("matches a route-backed link", function (assert) {
    const links = [
      { name: "one", route: "discovery.latest" },
      { name: "two", route: "discovery.unread" },
    ];

    const result = findActiveLink(
      links,
      routerStub({ active: ["discovery.unread"] })
    );

    assert.strictEqual(result.name, "two");
  });

  test("matches a link that only carries a URL", function (assert) {
    const links = [
      { name: "one", value: "/somewhere" },
      { name: "two", value: "/elsewhere" },
    ];

    const result = findActiveLink(
      links,
      routerStub({ currentURL: "/elsewhere" })
    );

    assert.strictEqual(result.name, "two", "user-built links match on href");
  });

  test("honours a boolean currentWhen", function (assert) {
    const links = [
      { name: "one", route: "discovery.latest", currentWhen: false },
      { name: "two", route: "discovery.latest", currentWhen: true },
    ];

    assert.strictEqual(findActiveLink(links, routerStub()).name, "two");
  });

  test("honours a space separated currentWhen", function (assert) {
    const links = [
      { name: "one", route: "a", currentWhen: "x y" },
      { name: "two", route: "b", currentWhen: "z discovery.latest" },
    ];

    const result = findActiveLink(
      links,
      routerStub({ active: ["discovery.latest"] })
    );

    assert.strictEqual(result.name, "two");
  });

  test("returns undefined when the router throws for every link", function (assert) {
    const links = [{ name: "one" }, { name: "two" }];

    assert.strictEqual(findActiveLink(links, routerStub()), undefined);
  });
});

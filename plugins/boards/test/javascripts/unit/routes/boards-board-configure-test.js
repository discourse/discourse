import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Route | boards-board-configure", function (hooks) {
  setupTest(hooks);

  test("redirects users who cannot manage the board", function (assert) {
    const route = this.owner.lookup("route:boards-board-configure");
    const replaceWith = sinon.stub(route.router, "replaceWith");

    route.afterModel(
      {
        board: {
          id: 42,
          slug: "team-board",
          can_manage: false,
        },
      },
      { to: { params: { slug: "team-board" } } }
    );

    assert.deepEqual(
      replaceWith.firstCall.args,
      ["boardsBoard", "team-board", 42],
      "the regular board route is used"
    );
  });

  test("keeps managers on the configure route", function (assert) {
    const route = this.owner.lookup("route:boards-board-configure");
    const replaceWith = sinon.stub(route.router, "replaceWith");

    route.afterModel(
      {
        board: {
          id: 42,
          slug: "team-board",
          can_manage: true,
        },
      },
      { to: { params: { slug: "team-board" } } }
    );

    assert.false(replaceWith.called, "no redirect occurs");
  });
});

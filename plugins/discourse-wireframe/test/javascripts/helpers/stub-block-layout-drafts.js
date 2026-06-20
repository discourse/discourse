import pretender, { response } from "discourse/tests/helpers/create-pretender";

/**
 * Registers a `beforeEach` that stubs the per-user drafts read endpoint to
 * return no drafts. The editor fetches drafts on `enter()`, so any test that
 * enters the editor but isn't about drafts would otherwise hit an unhandled
 * request. Call right after `setupTest(hooks)` / `setupRenderingTest(hooks)`.
 *
 * @param {object} hooks - the QUnit nested-module hooks.
 */
export function setupBlockLayoutDraftsStub(hooks) {
  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/wireframe/block-layout-drafts.json", () =>
      response({ drafts: [] })
    );
  });
}

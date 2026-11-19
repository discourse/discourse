import pretender, { response } from "discourse/tests/helpers/create-pretender";

/**
 * Registers a `beforeEach` that stubs the editor's on-entry plugin read — the
 * companion lookup (no saved layout). The editor fetches it on `enter()`, so any
 * test that enters the editor but isn't about it would otherwise hit an
 * unhandled request. Call right after `setupTest(hooks)` /
 * `setupRenderingTest(hooks)`; individual tests can override the stub.
 *
 * @param {object} hooks - the QUnit nested-module hooks.
 */
export function setupBlockLayoutDraftsStub(hooks) {
  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/wireframe/companion.json", () =>
      response({ companion_id: null })
    );
  });
}

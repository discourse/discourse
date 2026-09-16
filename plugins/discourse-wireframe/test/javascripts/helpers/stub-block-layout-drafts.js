import pretender, { response } from "discourse/tests/helpers/create-pretender";

/**
 * Registers a `beforeEach` that stubs the editor's on-entry plugin reads — the
 * per-user drafts endpoint (no drafts) and the companion lookup (no companion).
 * The editor fetches both on `enter()`, so any test that enters the editor but
 * isn't about them would otherwise hit an unhandled request. Call right after
 * `setupTest(hooks)` / `setupRenderingTest(hooks)`; individual tests can override
 * either stub.
 *
 * @param {object} hooks - the QUnit nested-module hooks.
 */
export function setupBlockLayoutDraftsStub(hooks) {
  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/wireframe/block-layout-drafts.json", () =>
      response({ drafts: [] })
    );
    pretender.get("/admin/plugins/wireframe/companion.json", () =>
      response({ companion_id: null })
    );
  });
}

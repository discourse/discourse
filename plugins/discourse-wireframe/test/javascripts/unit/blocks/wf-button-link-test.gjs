import { module, test } from "qunit";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WFButtonLink from "discourse/plugins/discourse-wireframe/discourse/blocks/wf-button-link";

module("Integration | Wireframe | wf:button-link block", function (hooks) {
  setupRenderingTest(hooks);

  test("requires a link URL", function (assert) {
    // A button that links nowhere is meaningless, so `href` is required.
    // The arg validator (`validateArgsAgainstSchema` in
    // `lib/blocks/-internals/validation/args.js`) checks `required` BEFORE
    // applying defaults, so the arg deliberately carries no `default` — a
    // default would always satisfy the check and the requirement would
    // never bite. We assert the schema declaration directly rather than
    // driving the render-time path, which rejects inside a tracked async
    // getter that escapes `assert.rejects`.
    const href = getBlockMetadata(WFButtonLink)?.args?.href;
    assert.true(href?.required, "href arg is marked required: true");
    assert.strictEqual(
      href?.default,
      undefined,
      "href declares no default, so required actually bites"
    );
  });

  test("requires at least one of label or icon", function (assert) {
    // A button with neither a label nor an icon renders as an empty
    // control, so the block declares an `atLeastOne` constraint over them.
    const constraints = getBlockMetadata(WFButtonLink)?.constraints;
    assert.deepEqual(
      constraints?.atLeastOne,
      ["label", "icon"],
      "atLeastOne constraint covers label and icon"
    );
  });
});

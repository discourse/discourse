import { module, test } from "qunit";
import Layout from "discourse/blocks/builtin/layout";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { MODE_PRESENTATION } from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-layout-form";

module("Unit | Discourse Wireframe | layout mode presentation", function () {
  // Drift guard: the inspector derives its mode picker from the block's live
  // `mode` enum but supplies each mode's icon/label from MODE_PRESENTATION. If
  // core adds a mode without a matching presentation entry, the picker would
  // silently drop it — this test fails first so the entry gets added.
  test("covers every value of core's layout mode enum", function (assert) {
    const modeEnum = getBlockMetadata(Layout).args.mode.enum;

    const missing = modeEnum.filter((id) => !(id in MODE_PRESENTATION));
    assert.deepEqual(
      missing,
      [],
      "every core layout mode has a presentation entry (icon + label)"
    );
  });
});

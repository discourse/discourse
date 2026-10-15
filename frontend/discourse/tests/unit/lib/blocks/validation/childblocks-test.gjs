import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { validateChildBlocks } from "discourse/lib/blocks/-internals/validation/block-decorator";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import { validateLayout } from "discourse/lib/blocks/-internals/validation/layout";

@block("wf-cb-parent", {
  container: true,
  childBlocks: ["wf-cb-allowed"],
})
class ParentBlock extends Component {
  <template>
    <div class="parent">{{yield}}</div>
  </template>
}

@block("wf-cb-allowed", {})
class AllowedBlock extends Component {
  <template>allowed</template>
}

@block("wf-cb-other", {})
class OtherBlock extends Component {
  <template>other</template>
}

module("Unit | Lib | blocks/validation/childBlocks", function (hooks) {
  setupTest(hooks);

  module("validateChildBlocks (decoration time)", function () {
    test("accepts a non-empty array of names on a container", function (assert) {
      validateChildBlocks("c", ["layout"], true);
      assert.true(true, "valid childBlocks accepted");
    });

    test("no-ops when childBlocks is null", function (assert) {
      validateChildBlocks("c", null, false);
      assert.true(true, "null is ignored");
    });

    test("rejects childBlocks on a non-container", function (assert) {
      assert.throws(
        () => validateChildBlocks("c", ["layout"], false),
        /only valid for container/,
        "non-container is rejected"
      );
    });

    test("rejects a non-array value", function (assert) {
      assert.throws(
        () => validateChildBlocks("c", "layout", true),
        /non-empty array/,
        "string is rejected"
      );
    });

    test("rejects an empty array", function (assert) {
      assert.throws(
        () => validateChildBlocks("c", [], true),
        /non-empty array/,
        "empty array is rejected"
      );
    });

    test("rejects a malformed block name", function (assert) {
      assert.throws(
        () => validateChildBlocks("c", ["Not A Name!"], true),
        /not a valid block name/,
        "malformed name is rejected"
      );
    });
  });

  module("validateLayout enforcement", function () {
    test("a child in the allow-list passes", async function (assert) {
      const blocksService = getOwner(this).lookup("service:blocks");
      await validateLayout(
        [{ block: ParentBlock, children: [{ block: AllowedBlock }] }],
        "homepage-blocks",
        blocksService,
        "",
        null,
        null,
        null,
        null,
        0,
        { seenIds: new Map() }
      );
      assert.true(true, "allowed child validated without error");
    });

    test("strict mode throws INVALID_CHILDREN for a disallowed child", async function (assert) {
      const blocksService = getOwner(this).lookup("service:blocks");
      await assert.rejects(
        validateLayout(
          [{ block: ParentBlock, children: [{ block: OtherBlock }] }],
          "homepage-blocks",
          blocksService,
          "",
          null,
          null,
          null,
          null,
          0,
          { seenIds: new Map() }
        ),
        /only accepts/,
        "rejects a child whose block is not in childBlocks"
      );
    });

    test("permissive mode stamps the parent with a soft failure", async function (assert) {
      const blocksService = getOwner(this).lookup("service:blocks");
      const parent = {
        block: ParentBlock,
        children: [{ block: OtherBlock }],
      };
      await validateLayout(
        [parent],
        "homepage-blocks",
        blocksService,
        "",
        null,
        null,
        null,
        null,
        0,
        { seenIds: new Map(), permissive: true, warnings: [] }
      );
      const codes = (parent.__failureDetails ?? []).map((d) => d.code);
      assert.true(
        codes.includes(ERROR_CODES.INVALID_CHILDREN),
        "the disallowed child is recorded as a soft failure, not thrown"
      );
    });
  });
});

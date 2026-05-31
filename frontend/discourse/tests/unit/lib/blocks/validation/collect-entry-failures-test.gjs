import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { ERROR_CODES } from "discourse/lib/blocks/-internals/validation/error-codes";
import {
  collectEntryFailures,
  validateLayout,
} from "discourse/lib/blocks/-internals/validation/layout";

@block("wf-cef-constrained", {
  args: {
    label: { type: "string" },
    icon: { type: "string" },
  },
  constraints: { atLeastOne: ["label", "icon"] },
})
class ConstrainedBlock extends Component {
  <template>x</template>
}

@block("wf-cef-required", {
  args: {
    href: { type: "string", required: true },
  },
})
class RequiredBlock extends Component {
  <template>x</template>
}

@block("wf-cef-required-and-constrained", {
  args: {
    href: { type: "string", required: true },
    label: { type: "string" },
    icon: { type: "string" },
  },
  constraints: { atLeastOne: ["label", "icon"] },
})
class RequiredAndConstrainedBlock extends Component {
  <template>x</template>
}

module("Unit | Lib | blocks/validation/collectEntryFailures", function (hooks) {
  setupTest(hooks);

  test("returns [] when args and constraints are satisfied", function (assert) {
    const details = collectEntryFailures(
      { args: { label: "Go" } },
      ConstrainedBlock
    );
    assert.deepEqual(details, []);
  });

  test("reports an unsatisfied constraint as a field-less detail", function (assert) {
    const details = collectEntryFailures({ args: {} }, ConstrainedBlock);
    assert.strictEqual(details.length, 1, "one detail");
    assert.strictEqual(details[0].code, ERROR_CODES.CONSTRAINT_VIOLATION);
    assert.strictEqual(
      details[0].field,
      undefined,
      "constraint errors carry no field"
    );
    assert.deepEqual(details[0].expected.fields, ["label", "icon"]);
  });

  test("reports a missing required arg as a field-level detail", function (assert) {
    const details = collectEntryFailures({ args: {} }, RequiredBlock);
    assert.strictEqual(details.length, 1, "one detail");
    assert.strictEqual(details[0].code, ERROR_CODES.REQUIRED_MISSING);
    assert.strictEqual(details[0].field, "href");
  });

  test("reports a bad arg AND an unmet constraint together", function (assert) {
    const details = collectEntryFailures(
      { args: {} },
      RequiredAndConstrainedBlock
    );
    const codes = details.map((d) => d.code);
    assert.true(
      codes.includes(ERROR_CODES.REQUIRED_MISSING),
      "the missing required arg is reported"
    );
    assert.true(
      codes.includes(ERROR_CODES.CONSTRAINT_VIOLATION),
      "the unmet constraint is reported in the same pass"
    );
  });

  test("returns [] for a block with no registered metadata", function (assert) {
    class Plain {}
    assert.deepEqual(collectEntryFailures({ args: {} }, Plain), []);
  });

  test("the full permissive+collect pass stamps args AND constraints together", async function (assert) {
    // Reproduces inserting a block whose URL is required and whose
    // label/icon constraint is also unmet: the inspector should show both,
    // not just the arg error (which used to short-circuit the constraint
    // check on the same pass).
    const entry = { block: RequiredAndConstrainedBlock, args: {} };
    const blocksService = getOwner(this).lookup("service:blocks");
    const context = {
      seenIds: new Map(),
      permissive: true,
      collect: true,
      warnings: [],
    };

    await validateLayout(
      [entry],
      "homepage-blocks",
      blocksService,
      "",
      null,
      null,
      null,
      null,
      0,
      context
    );

    const codes = (entry.__failureDetails ?? []).map((d) => d.code);
    assert.true(
      codes.includes(ERROR_CODES.REQUIRED_MISSING),
      "the missing required arg is stamped"
    );
    assert.true(
      codes.includes(ERROR_CODES.CONSTRAINT_VIOLATION),
      "the unmet constraint is stamped on the same pass"
    );
  });
});

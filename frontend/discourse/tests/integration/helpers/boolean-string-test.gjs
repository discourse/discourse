import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import booleanString from "discourse/helpers/boolean-string";
import {
  withSilencedDeprecations,
  withSilencedDeprecationsAsync,
} from "discourse/lib/deprecated";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Integration | Helper | boolean-string", function (hooks) {
  setupRenderingTest(hooks);

  test("preserves the legacy options contract", function (assert) {
    withSilencedDeprecations("discourse.boolean-string-helper", () => {
      const legacyHelper = globalThis.require(
        "discourse/helpers/boolean-string"
      ).default;
      assert.strictEqual(
        typeof legacyHelper,
        "function",
        "the public module exports a helper"
      );
      assert.strictEqual(booleanString(true), "true", "true is a string");

      for (const value of [false, null, undefined]) {
        assert.strictEqual(
          legacyHelper(value),
          undefined,
          "the public helper omits falsy values"
        );
        assert.strictEqual(
          legacyHelper(value, { omitFalse: false }),
          "false",
          "the public helper emits explicit false when requested"
        );
        assert.strictEqual(
          booleanString(value),
          undefined,
          `${value} is omitted by default`
        );
        assert.strictEqual(
          booleanString(value, { omitFalse: true }),
          undefined,
          `${value} is omitted when requested`
        );
        assert.strictEqual(
          booleanString(value, { omitFalse: false }),
          "false",
          `${value} is explicitly false when requested`
        );
        assert.strictEqual(
          booleanString(value, {}),
          "false",
          `an empty options object retains the legacy behavior for ${value}`
        );
      }

      assert.strictEqual(
        booleanString(true, { omitFalse: false }),
        "true",
        "explicit false does not affect true"
      );
    });
  });

  test("inline if preserves ARIA strings and omission across updates", async function (assert) {
    await withSilencedDeprecationsAsync(
      "discourse.boolean-string-helper",
      async () => {
        const serializeBoolean = globalThis.require(
          "discourse/helpers/boolean-string"
        ).default;
        this.set("value", false);

        await render(
          <template>
            <button
              aria-expanded={{serializeBoolean this.value omitFalse=false}}
              class="legacy-expanded"
              type="button"
            >Legacy</button>
            <input
              aria-invalid={{serializeBoolean this.value}}
              class="legacy-invalid"
            />
            <button
              aria-expanded={{if this.value "true" "false"}}
              class="inline-expanded"
              type="button"
            >Inline</button>
            <input
              aria-invalid={{if this.value "true"}}
              class="inline-invalid"
            />
          </template>
        );

        for (const value of [false, true, false, undefined, true, null]) {
          this.set("value", value);
          await settled();

          for (const selector of [".legacy", ".inline"]) {
            assert
              .dom(`${selector}-expanded`)
              .hasAttribute(
                "aria-expanded",
                value ? "true" : "false",
                `${selector} has an explicit state for ${value}`
              );

            if (value) {
              assert
                .dom(`${selector}-invalid`)
                .hasAttribute(
                  "aria-invalid",
                  "true",
                  `${selector} marks invalid`
                );
            } else {
              assert
                .dom(`${selector}-invalid`)
                .doesNotHaveAttribute(
                  "aria-invalid",
                  `${selector} omits invalid for ${value}`
                );
            }
          }
        }
      }
    );
  });

  test("deprecates direct and template calls with migration guidance", async function (assert) {
    const serializeBoolean = globalThis.require(
      "discourse/helpers/boolean-string"
    ).default;
    const warnStub = sinon.stub(console, "warn");
    const counterStub = sinon.stub(
      DeprecationCounter.prototype,
      "incrementCount"
    );
    disableRaiseOnDeprecation();

    try {
      assert.strictEqual(
        serializeBoolean(true),
        "true",
        "a truthy call keeps its return value"
      );
      assert.strictEqual(
        serializeBoolean(false),
        undefined,
        "an omitted false still triggers the warning"
      );

      await render(
        <template>
          <button
            aria-expanded={{serializeBoolean false omitFalse=false}}
            type="button"
          >Legacy</button>
        </template>
      );

      assert
        .dom("button")
        .hasAttribute(
          "aria-expanded",
          "false",
          "deprecated template usage still renders"
        );
      assert.strictEqual(
        warnStub.callCount,
        3,
        "each direct or template invocation emits a deprecation"
      );
      assert.deepEqual(
        counterStub.args,
        Array(3).fill(["discourse.boolean-string-helper", false]),
        "each warning goes through the Discourse deprecation pipeline"
      );
      for (const args of warnStub.args) {
        const warning = args.join(" ");
        assert.true(
          warning.includes("discourse.boolean-string-helper"),
          "the warning has a stable deprecation id"
        );
        assert.true(
          warning.includes('if value "true" "false"'),
          "the warning explains explicit false"
        );
        assert.true(
          warning.includes('if value "true"'),
          "the warning explains omitted false"
        );
      }
    } finally {
      counterStub.restore();
      warnStub.restore();
      enableRaiseOnDeprecation();
    }
  });
});

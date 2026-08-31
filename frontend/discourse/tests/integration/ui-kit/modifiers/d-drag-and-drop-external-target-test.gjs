import { tracked } from "@glimmer/tracking";
import { find, render, settled, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  externalDragOver,
  fileTransfer,
  simulateExternalDrag,
  textTransfer,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropExternalTarget, {
  registerDragAndDropExternalTarget,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";

module(
  "Integration | ui-kit | Modifier | dDragAndDropExternalTarget",
  function (hooks) {
    setupRenderingTest(hooks);

    test("registration marker follows the target lifecycle", async function (assert) {
      const state = new (class {
        @tracked show = true;
      })();

      await render(
        <template>
          {{#if state.show}}
            <div
              id="external-target"
              {{dDragAndDropExternalTarget accepts="files"}}
            >external target</div>
          {{/if}}
        </template>
      );

      const target = find("#external-target");
      assert.true(
        target.hasAttribute("data-drop-target-external"),
        "the target is marked while registered"
      );

      state.show = false;
      await settled();

      assert.false(
        target.hasAttribute("data-drop-target-external"),
        "destroying the target removes its marker"
      );
    });

    test("a lit target torn down mid-drag clears its class and mark without a leave", async function (assert) {
      const leaves = [];
      const recordLeave = () => leaves.push("leave");

      await render(
        <template>
          <div id="ext">ext</div>
        </template>
      );

      const cleanup = registerDragAndDropExternalTarget(find("#ext"), () => ({
        accepts: "text",
        onDragLeave: recordLeave,
      }));

      const dataTransfer = textTransfer();
      await externalDragOver("#ext", { dataTransfer });

      assert
        .dom("#ext")
        .hasClass("--drag-over-external", "lit while hovered")
        .hasAttribute("data-drop-target-external");

      cleanup();

      assert
        .dom("#ext")
        .doesNotHaveClass(
          "--drag-over-external",
          "the indicator does not outlive the registration"
        )
        .doesNotHaveAttribute(
          "data-drop-target-external",
          "and neither does the mark"
        );
      assert.deepEqual(
        leaves,
        [],
        "a registration that is going away reports no leave to a consumer that is going with it"
      );

      // The library still has the drag in flight; leaving the window ends it
      // rather than carrying it into the next test.
      await dragEvent("#ext", "dragleave", {
        dataTransfer,
        ...centerOf("#ext"),
      });
    });

    module("external target behaviour", function () {
      test("hands the consumer a payload it can read without importing the library", async function (assert) {
        let seen = null;
        const onDrop = ({ source }) => {
          seen = {
            containsFiles: source.containsFiles(),
            names: source.getFiles().map((file) => file.name),
          };
        };

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget accepts="files" onDrop=onDrop}}
            >ext</div>
          </template>
        );

        await simulateExternalDrag("#ext", { dataTransfer: fileTransfer() });

        assert.deepEqual(
          seen,
          { containsFiles: true, names: ["a.txt"] },
          "the decorated source answers about its own payload and returns the files"
        );
      });

      test("accepts filters which external kinds engage the target", async function (assert) {
        const drops = [];
        const onFilesDrop = () => drops.push("files");
        const onTextDrop = () => drops.push("text");

        await render(
          <template>
            <div
              id="files-only"
              {{dDragAndDropExternalTarget accepts="files" onDrop=onFilesDrop}}
            >files</div>
            <div
              id="text-only"
              {{dDragAndDropExternalTarget accepts="text" onDrop=onTextDrop}}
            >text</div>
          </template>
        );

        await simulateExternalDrag("#files-only", {
          dataTransfer: textTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "a text drag does not reach a target that only accepts files"
        );

        await simulateExternalDrag("#text-only", {
          dataTransfer: textTransfer(),
        });

        assert.deepEqual(
          drops,
          ["text"],
          "the same drag reaches the target whose kind it matches"
        );
      });

      test("a gate that turns false after the last dragover still lands the drop", async function (assert) {
        let allowed = true;
        let drops = 0;
        const canDrop = () => allowed;
        const onDrop = () => drops++;

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="files"
                canDrop=canDrop
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const dataTransfer = fileTransfer();
        await externalDragOver("#ext", { dataTransfer });

        // Turned off with no dragover left to observe it, so the release still
        // sees the target the last hover collected.
        allowed = false;
        await dragEvent("#ext", "drop", {
          dataTransfer,
          ...centerOf("#ext"),
        });

        assert.strictEqual(
          drops,
          1,
          "eligibility is sampled while hovering, not re-asked at the release"
        );
      });

      test("external drop position drives the same indicator classes the element target uses", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="text"
                axis="vertical"
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: { clientY: rect.top + 5 },
        });

        assert
          .dom("#ext")
          .hasClass("--drag-above", "the indicator marks the upper half")
          .doesNotHaveClass(
            "--drag-over-external",
            "and the positionless hover class is not also applied"
          );

        const lowerHalf = { clientY: rect.top + rect.height - 5 };
        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: lowerHalf,
        });

        assert
          .dom("#ext")
          .hasClass("--drag-below", "crossing the midpoint swaps the indicator")
          .doesNotHaveClass(
            "--drag-above",
            "rather than accumulating both positions"
          );

        await dragEvent("#ext", "drop", {
          dataTransfer,
          ...centerOf("#ext"),
          ...lowerHalf,
        });

        assert.deepEqual(
          drops,
          ["after"],
          "and the drop reports the side the indicator was showing"
        );
      });

      test("external drop position honours the horizontal axis", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="width: 200px"
              {{dDragAndDropExternalTarget
                accepts="text"
                axis="horizontal"
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();
        const nearLeftEdge = { clientX: rect.left + 5 };

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: nearLeftEdge,
        });

        assert
          .dom("#ext")
          .hasClass("--drag-left", "the indicator names the horizontal side")
          .doesNotHaveClass(
            "--drag-above",
            "and the class comes from the horizontal vocabulary, not the vertical one"
          );

        await dragEvent("#ext", "drop", {
          dataTransfer,
          ...centerOf("#ext"),
          ...nearLeftEdge,
        });

        assert.deepEqual(
          drops,
          ["before"],
          "the midpoint is measured along the named axis"
        );
      });

      test("external drop position takes a fixed position over the midpoint", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="text"
                position="inside"
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: { clientY: rect.top + 5 },
        });

        assert
          .dom("#ext")
          .hasClass(
            "--drag-inside",
            "a fixed position ignores which half the cursor is in"
          );

        await dragEvent("#ext", "drop", {
          dataTransfer,
          clientY: rect.top + 5,
          clientX: rect.left + 5,
        });

        assert.deepEqual(drops, ["inside"], "and reports itself on the drop");
      });

      test("external drop position is null once the drag leaves", async function (assert) {
        const seen = [];
        const onDragEnter = (payload) => seen.push(["enter", payload.position]);
        const onDragLeave = (payload) => seen.push(["leave", payload.position]);

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="text"
                axis="vertical"
                onDragEnter=onDragEnter
                onDragLeave=onDragLeave
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: { clientY: rect.top + 5 },
        });
        await dragEvent("#ext", "dragleave", {
          dataTransfer,
          ...centerOf("#ext"),
        });

        assert.deepEqual(
          seen,
          [
            ["enter", "before"],
            ["leave", null],
          ],
          "the position is where a drop would have landed while hovering, and nothing once there is nowhere to land"
        );
        assert
          .dom("#ext")
          .doesNotHaveClass("--drag-above", "and the indicator is dropped");
      });

      test("external drop position stays out of the way when neither arg is given", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget accepts="text" onDrop=onDrop}}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: { clientY: rect.top + 5 },
        });

        assert
          .dom("#ext")
          .hasClass(
            "--drag-over-external",
            "a target that asked for no position keeps the single hover class"
          )
          .doesNotHaveClass(
            "--drag-above",
            "rather than being opted into the positional vocabulary"
          );

        await dragEvent("#ext", "drop", {
          dataTransfer,
          clientY: rect.top + 5,
          clientX: rect.left + 5,
        });

        assert.deepEqual(
          drops,
          [null],
          "and reports no position, because it was never asked to resolve one"
        );
      });

      test("an external target switching between destination and slot mid-hover shows one indicator family", async function (assert) {
        const state = new (class {
          @tracked axis = undefined;
        })();

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget accepts="text" axis=state.axis}}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();
        const dataTransfer = textTransfer();
        const lowerHalf = {
          clientX: rect.left + 5,
          clientY: rect.top + rect.height - 5,
        };

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: lowerHalf,
        });

        assert
          .dom("#ext")
          .hasClass(
            "--drag-over-external",
            "a destination lights its one class"
          )
          .doesNotHaveClass("--drag-below");

        state.axis = "vertical";
        await settled();
        await dragEvent("#ext", "dragover", { dataTransfer, ...lowerHalf });

        assert
          .dom("#ext")
          .hasClass("--drag-below", "a slot lights the positional class")
          .doesNotHaveClass(
            "--drag-over-external",
            "and drops the destination class it had"
          );

        state.axis = undefined;
        await settled();
        await dragEvent("#ext", "dragover", { dataTransfer, ...lowerHalf });

        assert
          .dom("#ext")
          .hasClass("--drag-over-external", "back to a destination")
          .doesNotHaveClass(
            "--drag-below",
            "the positional class goes with it"
          );

        await dragEvent("#ext", "drop", { dataTransfer, ...lowerHalf });
      });
    });

    module("an external consumer that throws", function () {
      const blowUp = () => {
        throw new Error("external consumer blew up");
      };

      test("a throwing external drop effect function is reported and the drop still lands", async function (assert) {
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const drops = [];
        const recordDrop = () => drops.push("drop");

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="text"
                dropEffect=blowUp
                onDrop=recordDrop
              }}
            >ext</div>
          </template>
        );

        await simulateExternalDrag("#ext", { dataTransfer: textTransfer() });

        assert.deepEqual(
          drops,
          ["drop"],
          "the drop lands without an effect from the consumer"
        );
        assert.true(
          reported.length >= 1,
          `and the throwing effect gate was raised (${reported.length} seen)`
        );
      });

      test("a throwing external onDrag is reported and the drop still lands", async function (assert) {
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const drops = [];
        const recordDrop = ({ position }) => drops.push(position);

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="text"
                onDrag=blowUp
                onDrop=recordDrop
              }}
            >ext</div>
          </template>
        );

        await simulateExternalDrag("#ext", { dataTransfer: textTransfer() });

        assert.deepEqual(drops, [null], "the drop lands");
        assert.true(
          reported.length >= 1,
          `and the throwing drag callback was raised (${reported.length} seen)`
        );
      });

      test("a throwing external onDragLeave still clears the indicator and leaves the target usable", async function (assert) {
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const drops = [];
        const recordDrop = () => drops.push("drop");

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="text"
                onDragLeave=blowUp
                onDrop=recordDrop
              }}
            >ext</div>
          </template>
        );

        const dataTransfer = textTransfer();
        await externalDragOver("#ext", { dataTransfer });
        assert
          .dom("#ext")
          .hasClass("--drag-over-external", "lit while hovered");

        await dragEvent("#ext", "dragleave", {
          dataTransfer,
          ...centerOf("#ext"),
        });

        assert
          .dom("#ext")
          .doesNotHaveClass(
            "--drag-over-external",
            "the indicator is cleared even though the leave callback threw"
          );
        assert.strictEqual(reported.length, 1, "and the throw was raised once");

        await simulateExternalDrag("#ext", { dataTransfer: textTransfer() });

        assert.deepEqual(
          drops,
          ["drop"],
          "and the target still takes a drop afterwards"
        );
      });

      test("a throwing external onDragEnter does not cost the target its drop", async function (assert) {
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const drops = [];
        const recordDrop = ({ position }) => drops.push(position);
        const leaves = [];
        const recordLeave = () => leaves.push("leave");

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="text"
                onDragEnter=blowUp
                onDragLeave=recordLeave
                onDrop=recordDrop
              }}
            >ext</div>
          </template>
        );

        await simulateExternalDrag("#ext", { dataTransfer: textTransfer() });

        assert.deepEqual(
          drops,
          [null],
          "the drop still lands (with no position, since the target asked for none)"
        );
        assert.deepEqual(
          leaves,
          [],
          "a drop ends the drag without a leave, exactly as when the enter did not throw"
        );
        assert.strictEqual(
          reported.length,
          1,
          "and the throwing enter was raised once"
        );
      });
    });
  }
);

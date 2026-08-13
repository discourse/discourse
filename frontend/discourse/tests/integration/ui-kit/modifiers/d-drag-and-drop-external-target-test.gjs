import { tracked } from "@glimmer/tracking";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  externalDragOver,
  simulateExternalDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";

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

    module("external target behaviour", function () {
      function fileTransfer() {
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["payload"], "a.txt", { type: "text/plain" })
        );
        return dataTransfer;
      }

      function textTransfer() {
        const dataTransfer = new DataTransfer();
        dataTransfer.setData("text/plain", "dropped text");
        return dataTransfer;
      }

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
        assert
          .dom("#files-only")
          .doesNotHaveClass(
            "--drag-over-external",
            "and it lights no indicator on the way past"
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

      test("canDrop refuses a drop the accepts filter would have allowed", async function (assert) {
        let drops = 0;
        const onDrop = () => drops++;
        const canDrop = () => false;

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

        await simulateExternalDrag("#ext", { dataTransfer: fileTransfer() });

        assert.strictEqual(drops, 0, "the synchronous gate refuses the drop");
      });

      test("a gate that turns false after the last dragover refuses the drop", async function (assert) {
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

        // The library settles its target stack at the last dragover and does not
        // re-ask the gate at drop, so refusing here is this modifier's own doing.
        allowed = false;
        await dragEvent("#ext", "drop", {
          dataTransfer,
          ...centerOf("#ext"),
        });

        assert.strictEqual(
          drops,
          0,
          "a permission withdrawn before release does not act"
        );
      });

      test("indicator=false suppresses the hover class without refusing the drop", async function (assert) {
        let drops = 0;
        const onDrop = () => drops++;

        await render(
          <template>
            <div
              id="ext"
              {{dDragAndDropExternalTarget
                accepts="files"
                indicator=false
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const dataTransfer = fileTransfer();
        await externalDragOver("#ext", { dataTransfer });

        assert
          .dom("#ext")
          .doesNotHaveClass(
            "--drag-over-external",
            "the hover class is suppressed"
          );

        await dragEvent("#ext", "drop", { dataTransfer, ...centerOf("#ext") });

        assert.strictEqual(
          drops,
          1,
          "suppressing the indicator does not suppress the drop"
        );
      });

      test("external drop position resolves either side of the cursor midpoint", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="text"
                axis="y"
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();

        await simulateExternalDrag("#ext", {
          dataTransfer: textTransfer(),
          coordinates: { clientY: rect.top + 5 },
        });
        await simulateExternalDrag("#ext", {
          dataTransfer: textTransfer(),
          coordinates: { clientY: rect.top + rect.height - 5 },
        });

        assert.deepEqual(
          drops,
          ["before", "after"],
          "an external drop lands before or after the target depending on which side of its midpoint the cursor is"
        );
      });

      test("external drop position drives the same indicator classes the element target uses", async function (assert) {
        await render(
          <template>
            <div
              id="ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget accepts="text" axis="y"}}
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

        await externalDragOver("#ext", {
          dataTransfer,
          coordinates: { clientY: rect.top + rect.height - 5 },
        });

        assert
          .dom("#ext")
          .hasClass("--drag-below", "crossing the midpoint swaps the indicator")
          .doesNotHaveClass(
            "--drag-above",
            "rather than accumulating both positions"
          );
      });

      test("external drop position honours the x axis", async function (assert) {
        const drops = [];
        const onDrop = (payload) => drops.push(payload.position);

        await render(
          <template>
            <div
              id="ext"
              style="width: 200px"
              {{dDragAndDropExternalTarget
                accepts="text"
                axis="x"
                onDrop=onDrop
              }}
            >ext</div>
          </template>
        );

        const rect = find("#ext").getBoundingClientRect();

        await simulateExternalDrag("#ext", {
          dataTransfer: textTransfer(),
          coordinates: { clientX: rect.left + 5 },
        });

        assert.deepEqual(
          drops,
          ["before"],
          "the midpoint is measured along the named axis"
        );
        assert
          .dom("#ext")
          .doesNotHaveClass(
            "--drag-above",
            "and the class comes from the x vocabulary, not the y one"
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
                axis="y"
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
    });

    module("nested external targets", function () {
      test("an ancestor drops its indicator once a child becomes deepest", async function (assert) {
        await render(
          <template>
            <div
              id="outer-ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget accepts="files"}}
            >
              outer
              <div
                id="inner-ext"
                {{dDragAndDropExternalTarget accepts="files"}}
              >inner</div>
            </div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["x"], "a.txt", { type: "text/plain" })
        );
        const outerRect = find("#outer-ext").getBoundingClientRect();

        // No `dragstart`: a drag that begins outside the page is what makes this
        // the external adapter's rather than the element adapter's.
        await dragEvent("#outer-ext", "dragenter", {
          dataTransfer,
          clientX: outerRect.left + 5,
          clientY: outerRect.top + 5,
        });
        await dragEvent("#outer-ext", "dragover", {
          dataTransfer,
          clientX: outerRect.left + 5,
          clientY: outerRect.top + 5,
        });

        assert
          .dom("#outer-ext")
          .hasClass(
            "--drag-over-external",
            "the ancestor paints its indicator while it is the deepest target"
          );

        await dragEvent("#inner-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#inner-ext", "dragover", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });

        assert
          .dom("#inner-ext")
          .hasClass("--drag-over-external", "the child takes the indicator");
        assert
          .dom("#outer-ext")
          .doesNotHaveClass(
            "--drag-over-external",
            "and the ancestor gives it up, so only one zone is lit at a time"
          );
      });

      test("an external ancestor that never received an enter receives no leave", async function (assert) {
        const events = [];
        const onOuterEnter = () => events.push("outer:enter");
        const onOuterLeave = () => events.push("outer:leave");
        // The deepest target is the positive control, as in the element target's
        // equivalent: without it, dispatching no lifecycle callback at all would
        // satisfy the assertion below.
        const onInnerEnter = () => events.push("inner:enter");
        const onInnerLeave = () => events.push("inner:leave");

        await render(
          <template>
            <div
              id="outer-ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="files"
                onDragEnter=onOuterEnter
                onDragLeave=onOuterLeave
              }}
            >
              outer
              <div
                id="inner-ext"
                {{dDragAndDropExternalTarget
                  accepts="files"
                  onDragEnter=onInnerEnter
                  onDragLeave=onInnerLeave
                }}
              >inner</div>
            </div>
            <div
              id="away-ext"
              {{dDragAndDropExternalTarget accepts="files"}}
            >away</div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["x"], "a.txt", { type: "text/plain" })
        );

        // Straight onto the child, so the ancestor is in the stack but never the
        // deepest and so never forwards an enter.
        await dragEvent("#inner-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#inner-ext", "dragover", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#away-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#away-ext"),
        });
        await dragEvent("#away-ext", "dragover", {
          dataTransfer,
          ...centerOf("#away-ext"),
        });

        assert.deepEqual(
          events,
          ["inner:enter", "inner:leave"],
          "the deepest target is entered and left as a pair, and the ancestor that was never entered is never left"
        );
      });

      test("an external target that becomes deepest without a fresh enter is entered and left", async function (assert) {
        const events = [];
        let drags = 0;

        const onOuterEnter = () => events.push("outer:enter");
        const onOuterDrag = () => drags++;
        const onOuterLeave = () => events.push("outer:leave");

        await render(
          <template>
            <div
              id="outer-ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="files"
                onDragEnter=onOuterEnter
                onDrag=onOuterDrag
                onDragLeave=onOuterLeave
              }}
            >
              outer
              <div
                id="inner-ext"
                {{dDragAndDropExternalTarget accepts="files"}}
              >inner</div>
            </div>
            <div
              id="away-ext"
              {{dDragAndDropExternalTarget accepts="files"}}
            >away</div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["x"], "a.txt", { type: "text/plain" })
        );
        const outerRect = find("#outer-ext").getBoundingClientRect();

        // Onto the child first, so the ancestor joins the hierarchy while the
        // child is deepest and its own enter is swallowed.
        await dragEvent("#inner-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#inner-ext", "dragover", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });

        // Back onto the ancestor's own area. It becomes deepest without a fresh
        // enter, because it never left the hierarchy.
        await dragEvent("#outer-ext", "dragover", {
          dataTransfer,
          clientX: outerRect.left + 5,
          clientY: outerRect.top + 5,
        });

        await dragEvent("#away-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#away-ext"),
        });
        await dragEvent("#away-ext", "dragover", {
          dataTransfer,
          ...centerOf("#away-ext"),
        });

        assert.true(
          drags > 0,
          "the ancestor was told about the drag once it was the deepest target"
        );
        assert.deepEqual(
          events,
          ["outer:enter", "outer:leave"],
          "so it is entered when it takes over and left when it gives up, matching the element target"
        );
      });

      test("an external ancestor superseded by a child is left before the drop lands", async function (assert) {
        const events = [];
        const onOuterEnter = () => events.push("outer:enter");
        const onOuterLeave = () => events.push("outer:leave");
        const onInnerDrop = () => events.push("inner:drop");

        await render(
          <template>
            <div
              id="outer-ext"
              style="height: 100px"
              {{dDragAndDropExternalTarget
                accepts="files"
                onDragEnter=onOuterEnter
                onDragLeave=onOuterLeave
              }}
            >
              outer
              <div
                id="inner-ext"
                {{dDragAndDropExternalTarget
                  accepts="files"
                  onDrop=onInnerDrop
                }}
              >inner</div>
            </div>
          </template>
        );

        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["x"], "a.txt", { type: "text/plain" })
        );
        const outerRect = find("#outer-ext").getBoundingClientRect();

        // The ancestor's own area first, so it is genuinely entered.
        await dragEvent("#outer-ext", "dragenter", {
          dataTransfer,
          clientX: outerRect.left + 5,
          clientY: outerRect.top + 5,
        });
        await dragEvent("#outer-ext", "dragover", {
          dataTransfer,
          clientX: outerRect.left + 5,
          clientY: outerRect.top + 5,
        });

        await dragEvent("#inner-ext", "dragenter", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#inner-ext", "dragover", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });
        await dragEvent("#inner-ext", "drop", {
          dataTransfer,
          ...centerOf("#inner-ext"),
        });

        assert.deepEqual(
          events,
          ["outer:enter", "outer:leave", "inner:drop"],
          "the ancestor is left as soon as the child takes over, so a drop never lands with its enter still open"
        );
      });
    });
  }
);

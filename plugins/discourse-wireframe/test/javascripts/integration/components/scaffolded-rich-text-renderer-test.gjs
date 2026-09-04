import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ScaffoldedRichTextRenderer from "discourse/plugins/discourse-wireframe/discourse/components/scaffolded-rich-text-renderer";

const NO_RUNS = [];

module(
  "Integration | discourse-wireframe | scaffolded-rich-text-renderer",
  function (hooks) {
    setupRenderingTest(hooks);

    test("emits the dedicated rich-text marker carrying the arg name", async function (assert) {
      await render(
        <template>
          <ScaffoldedRichTextRenderer
            @arg="title"
            @schema="paragraph"
            @isEmpty={{true}}
            @placeholder="Title"
            @runs={{NO_RUNS}}
          />
        </template>
      );

      // The in-place text subsystem (tab navigation + editor mount target) keys
      // off this dedicated marker, NOT the generic `data-block-arg`, so only
      // real rich-text fields are reachable for inline editing.
      assert
        .dom("[data-wf-rich-text-arg]")
        .exists("the rich-text field carries the rich-text marker")
        .hasAttribute(
          "data-wf-rich-text-arg",
          "title",
          "the marker carries the arg name"
        );
    });
  }
);

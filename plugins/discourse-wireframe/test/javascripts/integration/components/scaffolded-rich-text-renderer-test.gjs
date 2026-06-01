import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ScaffoldedRichTextRenderer from "discourse/plugins/discourse-wireframe/discourse/components/scaffolded-rich-text-renderer";

const NO_RUNS = [];

module(
  "Integration | discourse-wireframe | scaffolded-rich-text-renderer",
  function (hooks) {
    setupRenderingTest(hooks);

    test("emits the dedicated inline-edit marker carrying the arg name", async function (assert) {
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

      // The inline-edit subsystem (tab navigation + editor mount target) keys
      // off this dedicated marker, NOT the generic `data-block-arg`, so only
      // real rich-text fields are reachable for inline editing.
      assert
        .dom("[data-wf-inline-edit-arg]")
        .exists("the rich-text field carries the inline-edit marker")
        .hasAttribute(
          "data-wf-inline-edit-arg",
          "title",
          "the marker carries the arg name"
        );
    });
  }
);

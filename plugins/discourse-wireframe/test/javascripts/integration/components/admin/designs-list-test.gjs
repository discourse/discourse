import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DesignsList from "discourse/plugins/discourse-wireframe/discourse/components/admin/designs-list";

const DESIGNS = [
  {
    id: 2,
    name: "Spring",
    theme_id: -1,
    theme_name: "Foundation",
    active: true,
    updated_at: "2026-11-10T12:00:00Z",
  },
  {
    id: 3,
    name: "Autumn",
    theme_id: -1,
    theme_name: "Foundation",
    active: false,
    updated_at: "2026-11-09T12:00:00Z",
  },
];

module(
  "Integration | discourse-wireframe | Component | admin designs list",
  function (hooks) {
    setupRenderingTest(hooks);

    test("lists each design with its theme and status", async function (assert) {
      await render(<template><DesignsList @designs={{DESIGNS}} /></template>);

      assert.dom(".wireframe-designs__row").exists({ count: 2 });
      assert
        .dom(".wireframe-designs__row[data-design-id='2']")
        .includesText("Foundation", "names the design's theme");
      assert
        .dom(".wireframe-designs__status.--active")
        .exists({ count: 1 }, "marks the design in use");
      assert
        .dom(
          ".wireframe-designs__row[data-design-id='2'] .wireframe-designs__use"
        )
        .doesNotExist("the design in use can't be switched to");
      assert
        .dom(
          ".wireframe-designs__row[data-design-id='3'] .wireframe-designs__use"
        )
        .exists("another design can be put in use");
    });

    test("shows an empty state with no designs", async function (assert) {
      await render(<template><DesignsList @designs={{(array)}} /></template>);

      assert.dom(".wireframe-designs__table").doesNotExist();
      assert.dom(".admin-config-area-empty-list").exists();
    });
  }
);

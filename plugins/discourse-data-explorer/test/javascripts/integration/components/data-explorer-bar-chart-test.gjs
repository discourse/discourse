import { array } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DataExplorerBarChart from "../../discourse/components/data-explorer-bar-chart";

module(
  "Data Explorer Plugin | Integration | Component | data-explorer-bar-chart",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a chart", async function (assert) {
      await render(
        <template>
          <DataExplorerBarChart
            @labels={{array "label_1" "label_2"}}
            @values={{array 115 1000}}
            @datasetName="data"
          />
        </template>
      );

      assert.dom("canvas").exists("renders a canvas");
    });
  }
);

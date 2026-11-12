import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { transformerWasAdded } from "discourse/lib/transformer";
import { assignedListRequestParams } from "discourse/plugins/discourse-assign/discourse/lib/assigned-list-query-params";

module(
  "Discourse Assign | Unit | Lib | assigned-list-query-params",
  function (hooks) {
    setupTest(hooks);

    test("exposes the assigned-list-query-params transformer to plugins", function (assert) {
      assert.true(transformerWasAdded("assigned-list-query-params", "VALUE"));
    });

    test("assignedListRequestParams merges transformer params, dropping cleared ones", function (assert) {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "assigned-list-query-params",
          ({ value }) => ({ ...value, lib_param: { refreshModel: true } })
        );
      });

      assert.deepEqual(
        assignedListRequestParams({ lib_param: "open" }, { order: "views" }),
        { order: "views", lib_param: "open" }
      );

      assert.deepEqual(
        assignedListRequestParams(
          { lib_param: "" },
          { order: "views", lib_param: "stale" }
        ),
        { order: "views" }
      );
    });
  }
);

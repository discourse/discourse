import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import AssignedController from "discourse/plugins/discourse-assign/discourse/controllers/user-activity/assigned";

module(
  "Discourse Assign | Unit | Controller | user-activity/assigned",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "assigned-list-query-params",
          ({ value }) => ({ ...value, fake_status: { refreshModel: true } })
        );
      });

      this.owner.register(
        "controller:user-activity/assigned",
        AssignedController
      );
      this.requests = [];

      const requests = this.requests;
      this.owner.lookup("service:store").findFiltered = async (
        _type,
        { filter, params }
      ) => {
        requests.push(params);
        // like the topic list adapter, the returned list keeps request params
        return { loaded: true, filter, params };
      };
    });

    test("refreshModel keeps registered query params, and drops cleared ones", async function (assert) {
      const controller = this.owner.lookup("controller:user-activity/assigned");
      controller.set("model", {
        filter: "topics/messages-assigned/martina",
        params: { exclude_category_ids: [-1], fake_status: "In Development" },
      });
      controller.setProperties({
        fake_status: "In Development",
        order: "views",
      });

      await controller.refreshModel();

      assert.deepEqual(this.requests[0], {
        exclude_category_ids: [-1],
        fake_status: "In Development",
        order: "views",
        ascending: false,
        search: "",
      });

      controller.set("fake_status", undefined);
      await controller.refreshModel();

      assert.deepEqual(this.requests[1], {
        exclude_category_ids: [-1],
        order: "views",
        ascending: false,
        search: "",
      });
    });
  }
);

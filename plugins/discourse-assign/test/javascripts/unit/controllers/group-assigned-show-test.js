import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import GroupAssignedController from "discourse/plugins/discourse-assign/discourse/controllers/group/assigned/show";

module(
  "Discourse Assign | Unit | Controller | group/assigned/show",
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
        "controller:group/assigned/show",
        GroupAssignedController
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

    test("refreshModel keeps registered params and the direct scope flag", async function (assert) {
      const controller = this.owner.lookup("controller:group/assigned/show");
      controller.set("model", {
        filter: "topics/group-topics-assigned/hubspot",
        params: { direct: true, fake_status: "In Development" },
      });
      controller.setProperties({
        fake_status: "In Development",
        order: "views",
      });

      await controller.refreshModel();

      assert.deepEqual(this.requests[0], {
        order: "views",
        ascending: false,
        search: "",
        direct: true,
        fake_status: "In Development",
      });

      controller.set("fake_status", "");
      await controller.refreshModel();

      assert.deepEqual(this.requests[1], {
        order: "views",
        ascending: false,
        search: "",
        direct: true,
      });
    });
  }
);

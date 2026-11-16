import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import GroupAssignedRoute from "discourse/plugins/discourse-assign/discourse/routes/group/assigned/show";

module(
  "Discourse Assign | Unit | Route | group/assigned/show",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      withPluginApi((api) => {
        api.registerValueTransformer(
          "assigned-list-query-params",
          ({ value }) => ({ ...value, fake_status: { refreshModel: true } })
        );
      });

      this.owner.register("route:group/assigned/show", GroupAssignedRoute);
      this.route = this.owner.lookup("route:group/assigned/show");
      this.route.modelFor = () => ({ name: "hubspot" });
      this.session = this.owner.lookup("service:session");

      this.requests = [];
      const requests = this.requests;
      this.owner.lookup("service:store").findFiltered = async (
        _type,
        { filter, params }
      ) => {
        requests.push(params);
        return { loaded: true, filter, params };
      };
    });

    test("a narrowed request bypasses the session cache", async function (assert) {
      const filter = "topics/group-topics-assigned/hubspot";
      this.session.set("topicList", { filter, params: {} });

      await this.route.model({
        filter: "everyone",
        fake_status: "In Development",
      });

      assert.strictEqual(this.requests.length, 1);
      assert.strictEqual(this.requests[0].fake_status, "In Development");
    });

    test("a cached list narrowed by a registered param is not reused once the filter is cleared", async function (assert) {
      const filter = "topics/group-topics-assigned/hubspot";
      // what TopicList.loadMore leaves behind after paginating a filtered queue
      this.session.set("topicList", {
        filter,
        params: { fake_status: "In Development", direct: false },
      });

      await this.route.model({ filter: "everyone" });

      assert.strictEqual(this.requests.length, 1);
    });

    test("an unfiltered cached list is still reused", async function (assert) {
      const filter = "topics/group-topics-assigned/hubspot";
      const cached = {
        filter,
        params: { order: "", search: "", direct: false },
      };
      this.session.set("topicList", cached);

      const model = await this.route.model({ filter: "everyone" });

      assert.strictEqual(model, cached);
      assert.strictEqual(this.requests.length, 0);
    });
  }
);

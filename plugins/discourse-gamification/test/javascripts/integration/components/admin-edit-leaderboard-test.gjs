import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminEditLeaderboard from "discourse/plugins/discourse-gamification/admin/components/admin-edit-leaderboard";

module(
  "Discourse Gamification | Integration | Component | admin-edit-leaderboard",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      sinon.restore();
    });

    test("loads selected scorable categories asynchronously", async function (assert) {
      const category = Category.findById(1001);

      this.site.lazy_load_categories = true;

      sinon.stub(Category, "findById").returns(null);
      const asyncFindByIdsStub = sinon
        .stub(Category, "asyncFindByIds")
        .resolves([category]);

      this.leaderboard = {
        id: 1,
        name: "Leaderboard",
        fromDate: null,
        toDate: null,
        includedGroupsIds: [],
        excludedGroupsIds: [],
        visibleToGroupsIds: [],
        defaultPeriod: 0,
        periodFilterDisabled: false,
        scoreOverrides: null,
        scorableCategoryIds: [1001],
      };

      await render(
        <template>
          <AdminEditLeaderboard @leaderboard={{this.leaderboard}} />
        </template>
      );

      assert.true(asyncFindByIdsStub.calledWith([1001]));
    });
  }
);

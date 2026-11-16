import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AdminEditLeaderboard from "discourse/plugins/discourse-gamification/admin/components/admin-edit-leaderboard";
import GamificationLeaderboard from "discourse/plugins/discourse-gamification/discourse/models/gamification-leaderboard";

module(
  "Discourse Gamification | Integration | Component | AdminEditLeaderboard",
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
        defaultPeriodId: 0,
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

    test("preserves the default period when saving another field", async function (assert) {
      this.leaderboard = GamificationLeaderboard.create({
        id: 1,
        name: "Leaderboard",
        default_period: 4,
      });

      const router = this.owner.lookup("service:router");
      sinon.stub(router, "transitionTo").resolves();
      sinon.stub(router, "refresh");

      let savedData;
      pretender.put("/admin/plugins/gamification/leaderboard/1", (request) => {
        savedData = new URLSearchParams(request.requestBody);
        return response({ success: true });
      });

      await render(
        <template>
          <AdminEditLeaderboard @leaderboard={{this.leaderboard}} />
        </template>
      );

      assert.strictEqual(
        selectKit(".period-input").header().value(),
        "4",
        "the saved weekly period is selected"
      );

      await form().field("name").fillIn("Renamed leaderboard");
      await form().submit();

      assert.strictEqual(
        savedData.get("name"),
        "Renamed leaderboard",
        "the name changes"
      );
      assert.strictEqual(
        savedData.get("default_period"),
        "4",
        "the period remains weekly"
      );
    });
  }
);

import { module, test } from "qunit";
import RecentTopics from "discourse/blocks/builtin/recent-topics";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

module("Unit | Blocks | recent-topics solved visibility", function () {
  const visible = (args, siteSettings, categories = []) =>
    getBlockMetadata(RecentTopics).args.solved.ui.visibleWhen({
      args,
      siteSettings,
      site: { categories },
    });

  const categories = [
    { id: 1, custom_fields: { enable_accepted_answers: "true" } },
    { id: 2, custom_fields: { enable_accepted_answers: "false" } },
    { id: 3 },
  ];

  test("hidden when solving topics is disabled", function (assert) {
    assert.false(
      visible({ categoryId: 1 }, { solved_enabled: false }, categories)
    );
  });

  test("hidden when no category is selected", function (assert) {
    assert.false(visible({}, { solved_enabled: true }, categories));
  });

  test("hidden when the selected category does not allow solved topics", function (assert) {
    assert.false(
      visible({ categoryId: 2 }, { solved_enabled: true }, categories)
    );
    assert.false(
      visible({ categoryId: 3 }, { solved_enabled: true }, categories)
    );
  });

  test("shown when the selected category allows solved topics", function (assert) {
    assert.true(
      visible({ categoryId: 1 }, { solved_enabled: true }, categories)
    );
  });

  test("shown when every topic can be solved", function (assert) {
    assert.true(
      visible({}, { solved_enabled: true, allow_solved_on_all_topics: true })
    );
  });
});

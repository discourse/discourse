import { click } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import Topic from "discourse/models/topic";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | topic-list", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("bulk select", {
    template: hbs`{{topic-list
        canBulkSelect=true
        toggleBulkSelect=toggleBulkSelect
        bulkSelectEnabled=bulkSelectEnabled
        autoAddTopicsToBulkSelect=autoAddTopicsToBulkSelect
        updateAutoAddTopicsToBulkSelect=updateAutoAddTopicsToBulkSelect
        topics=topics
        selected=selected
      }}`,

    beforeEach() {
      const topic = Topic.create({ id: 24234 });
      const topic2 = Topic.create({ id: 24235 });
      this.setProperties({
        topics: [topic, topic2],
        selected: [],
        bulkSelectEnabled: false,
        autoAddTopicsToBulkSelect: false,

        toggleBulkSelect() {
          this.toggleProperty("bulkSelectEnabled");
        },

        updateAutoAddTopicsToBulkSelect(newVal) {
          this.set("autoAddTopicsToBulkSelect", newVal);
        },
      });
    },

    async test(assert) {
      assert.strictEqual(this.selected.length, 0, "defaults to 0");
      await click("button.bulk-select");
      assert.ok(this.bulkSelectEnabled, "bulk select is enabled");

      await click("button.bulk-select-all");
      assert.strictEqual(
        this.selected.length,
        2,
        "clicking Select All selects all loaded topics"
      );
      assert.ok(
        this.autoAddTopicsToBulkSelect,
        "clicking Select All turns on the autoAddTopicsToBulkSelect flag"
      );

      await click("button.bulk-clear-all");
      assert.strictEqual(
        this.selected.length,
        0,
        "clicking Clear All deselects all topics"
      );
      assert.ok(
        !this.autoAddTopicsToBulkSelect,
        "clicking Clear All turns off the autoAddTopicsToBulkSelect flag"
      );
    },
  });
});

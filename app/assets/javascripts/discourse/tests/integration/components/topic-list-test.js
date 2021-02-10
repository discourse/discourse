import { click } from "@ember/test-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import Topic from "discourse/models/topic";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | topic-list", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("checkbox is rendered checked if topic is in selected array", {
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
      await click("button.bulk-select");
      assert.ok(this.bulkSelectEnabled);

      await click("button.bulk-select-all");
      assert.equal(this.selected.length, 2);
      assert.ok(this.autoAddTopicsToBulkSelect);

      await click("button.bulk-clear-all");
      assert.equal(this.selected.length, 0);
      assert.ok(!this.autoAddTopicsToBulkSelect);
    },
  });
});

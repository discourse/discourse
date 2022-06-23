import { hbs } from "ember-cli-htmlbars";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import Topic from "discourse/models/topic";

discourseModule("Integration | Component | topic-list-item", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("checkbox is rendered checked if topic is in selected array", {
    template: hbs`{{topic-list-item
        topic=topic
        bulkSelectEnabled=true
        selected=selected
      }}
      {{topic-list-item
        topic=topic2
        bulkSelectEnabled=true
        selected=selected
      }}`,

    beforeEach() {
      const topic = Topic.create({ id: 24234 });
      const topic2 = Topic.create({ id: 24235 });
      this.setProperties({
        topic,
        topic2,
        selected: [topic],
      });
    },

    async test(assert) {
      const checkboxes = queryAll("input.bulk-select");
      assert.ok(checkboxes[0].checked);
      assert.ok(!checkboxes[1].checked);
    },
  });
});

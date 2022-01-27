import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import { click } from "@ember/test-helpers";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | topic-status",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("basics", {
      template: hbs`{{mount-widget widget="topic-status" args=args}}`,
      beforeEach(store) {
        this.set("args", {
          topic: store.createRecord("topic", { closed: true }),
          disableActions: true,
        });
      },
      test(assert) {
        assert.ok(exists(".topic-status .d-icon-lock"));
      },
    });

    componentTest("extendability", {
      template: hbs`{{mount-widget widget="topic-status" args=args}}`,
      beforeEach(store) {
        TopicStatusIcons.addObject([
          "has_accepted_answer",
          "far-check-square",
          "solved",
        ]);
        this.set("args", {
          topic: store.createRecord("topic", {
            has_accepted_answer: true,
          }),
          disableActions: true,
        });
      },
      test(assert) {
        assert.ok(exists(".topic-status .d-icon-far-check-square"));
      },
    });

    componentTest("toggling pin status", {
      template: hbs`{{mount-widget widget="topic-status" args=args}}`,
      beforeEach(store) {
        this.set("args", {
          topic: store.createRecord("topic", { closed: true, pinned: true }),
        });
      },
      async test(assert) {
        assert.ok(exists(".topic-statuses .pinned"), "pinned icon is shown");
        assert.ok(
          !exists(".topic-statuses .unpinned"),
          "unpinned icon is not shown"
        );

        await click(".topic-statuses .pin-toggle-button");

        assert.ok(
          !exists(".topic-statuses .pinned"),
          "pinned icon is not shown"
        );
        assert.ok(
          exists(".topic-statuses .unpinned"),
          "unpinned icon is shown"
        );

        await click(".topic-statuses .pin-toggle-button");

        assert.ok(exists(".topic-statuses .pinned"), "pinned icon is shown");
        assert.ok(
          !exists(".topic-statuses .unpinned"),
          "unpinned icon is not shown"
        );
      },
    });
  }
);

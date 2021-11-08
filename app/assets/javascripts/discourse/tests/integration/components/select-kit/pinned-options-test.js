import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import Topic from "discourse/models/topic";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const buildTopic = function (pinned = true) {
  return Topic.create({
    id: 1234,
    title: "Qunit Test Topic",
    deleted_at: new Date(),
    pinned,
  });
};

discourseModule(
  "Integration | Component | select-kit/pinned-options",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("unpinning", {
      template: hbs`{{pinned-options value=topic.pinned topic=topic}}`,

      beforeEach() {
        this.siteSettings.automatically_unpin_topics = false;
        this.set("topic", buildTopic());
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().name(), "pinned");

        await this.subject.expand();
        await this.subject.selectRowByValue("unpinned");

        assert.strictEqual(this.subject.header().name(), "unpinned");
      },
    });

    componentTest("pinning", {
      template: hbs`{{pinned-options value=topic.pinned topic=topic}}`,

      beforeEach() {
        this.siteSettings.automatically_unpin_topics = false;
        this.set("topic", buildTopic(false));
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().name(), "unpinned");

        await this.subject.expand();
        await this.subject.selectRowByValue("pinned");

        assert.strictEqual(this.subject.header().name(), "pinned");
      },
    });
  }
);

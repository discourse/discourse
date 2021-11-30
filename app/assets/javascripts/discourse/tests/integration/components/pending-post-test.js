import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import createStore from "discourse/tests/helpers/create-store";

discourseModule("Integration | Component | pending-post", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("it renders", {
    template: hbs`<PendingPost @post={{this.post}}/>`,

    beforeEach() {
      const store = createStore();
      store.createRecord("category", { id: 2 });
      const post = store.createRecord("pending-post", {
        id: 1,
        topic_url: "topic-url",
        username: "USERNAME",
        category_id: 2,
        raw_text: "**bold text**",
      });
      this.set("post", post);
    },

    test(assert) {
      assert.strictEqual(
        query("p.excerpt").textContent.trim(),
        "bold text",
        "renders the cooked text"
      );
    },
  });
});

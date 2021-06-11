import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { count, discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | actions-summary",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("post deleted", {
      template: hbs`{{mount-widget widget="actions-summary" args=args}}`,
      beforeEach() {
        this.set("args", {
          deleted_at: "2016-01-01",
          deletedByUsername: "eviltrout",
          deletedByAvatarTemplate: "/images/avatar.png",
        });
      },
      test(assert) {
        assert.equal(
          count(".post-action .d-icon-far-trash-alt"),
          1,
          "it has the deleted icon"
        );
        assert.equal(
          count(".avatar[title=eviltrout]"),
          1,
          "it has the deleted by avatar"
        );
      },
    });
  }
);

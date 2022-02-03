import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | ace-editor", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("css editor", {
    template: hbs`{{ace-editor mode="css"}}`,
    test(assert) {
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("html editor", {
    template: hbs`{{ace-editor mode="html" content="<b>wat</b>"}}`,
    test(assert) {
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("sql editor", {
    template: hbs`{{ace-editor mode="sql" content="SELECT * FROM users"}}`,
    test(assert) {
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("disabled editor", {
    template: hbs`
      {{ace-editor mode="sql" content="SELECT * FROM users" disabled=true}}
    `,
    test(assert) {
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
      assert.equal(
        queryAll(".ace-wrapper[data-disabled]").length,
        1,
        "it has a data-disabled attr"
      );
    },
  });
});

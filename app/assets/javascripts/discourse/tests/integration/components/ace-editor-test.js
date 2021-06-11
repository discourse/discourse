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
    skip: true,
    template: hbs`{{ace-editor mode="css"}}`,
    test(assert) {
      assert.expect(1);
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("html editor", {
    skip: true,
    template: hbs`{{ace-editor mode="html" content="<b>wat</b>"}}`,
    test(assert) {
      assert.expect(1);
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("sql editor", {
    skip: true,
    template: hbs`{{ace-editor mode="sql" content="SELECT * FROM users"}}`,
    test(assert) {
      assert.expect(1);
      assert.ok(exists(".ace_editor"), "it renders the ace editor");
    },
  });

  componentTest("disabled editor", {
    skip: true,
    template: hbs`
      {{ace-editor mode="sql" content="SELECT * FROM users" disabled=true}}
    `,
    test(assert) {
      const $ace = queryAll(".ace_editor");
      assert.expect(3);
      assert.ok($ace.length, "it renders the ace editor");
      assert.equal(
        $ace.parent().data().editor.getReadOnly(),
        true,
        "it sets ACE to read-only mode"
      );
      assert.equal(
        $ace.parent().attr("data-disabled"),
        "true",
        "ACE wrapper has `data-disabled` attribute set to true"
      );
    },
  });
});

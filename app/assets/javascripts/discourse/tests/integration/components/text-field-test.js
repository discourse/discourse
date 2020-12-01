import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { fillIn } from "@ember/test-helpers";
import sinon from "sinon";

discourseModule("Integration | Component | text-field", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("renders correctly with no properties set", {
    template: `{{text-field}}`,

    test(assert) {
      assert.ok(queryAll("input[type=text]").length);
    },
  });

  componentTest("support a placeholder", {
    template: `{{text-field placeholderKey="placeholder.i18n.key"}}`,

    beforeEach() {
      sinon.stub(I18n, "t").returnsArg(0);
    },

    test(assert) {
      assert.ok(queryAll("input[type=text]").length);
      assert.equal(
        queryAll("input").prop("placeholder"),
        "placeholder.i18n.key"
      );
    },
  });

  componentTest("sets the dir attribute to ltr for Hebrew text", {
    template: `{{text-field value='זהו שם עברי עם מקום עברי'}}`,
    beforeEach() {
      this.siteSettings.support_mixed_text_direction = true;
    },

    test(assert) {
      assert.equal(queryAll("input").attr("dir"), "rtl");
    },
  });

  componentTest("sets the dir attribute to ltr for English text", {
    template: `{{text-field value='This is a ltr title'}}`,
    beforeEach() {
      this.siteSettings.support_mixed_text_direction = true;
    },

    test(assert) {
      assert.equal(queryAll("input").attr("dir"), "ltr");
    },
  });

  componentTest("supports onChange", {
    template: `{{text-field class="tf-test" value=value onChange=changed}}`,
    beforeEach() {
      this.called = false;
      this.newValue = null;
      this.set("value", "hello");
      this.set("changed", (v) => {
        this.newValue = v;
        this.called = true;
      });
    },
    async test(assert) {
      await fillIn(".tf-test", "hello");
      assert.ok(!this.called);
      await fillIn(".tf-test", "new text");
      assert.ok(this.called);
      assert.equal(this.newValue, "new text");
    },
  });

  componentTest("supports onChangeImmediate", {
    template: `{{text-field class="tf-test" value=value onChangeImmediate=changed}}`,
    beforeEach() {
      this.called = false;
      this.newValue = null;
      this.set("value", "old");
      this.set("changed", (v) => {
        this.newValue = v;
        this.called = true;
      });
    },
    async test(assert) {
      await fillIn(".tf-test", "old");
      assert.ok(!this.called);
      await fillIn(".tf-test", "no longer old");
      assert.ok(this.called);
      assert.equal(this.newValue, "no longer old");
    },
  });
});

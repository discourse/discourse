import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

function paste(element, text) {
  let e = new Event("paste");
  e.clipboardData = { getData: () => text };
  element.dispatchEvent(e);
}

discourseModule("Integration | Component | user-selector", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("pasting a list of usernames", {
    template: hbs`{{user-selector usernames=usernames class="test-selector"}}`,

    beforeEach() {
      this.set("usernames", "evil,trout");
    },

    test(assert) {
      let element = query(".test-selector");

      assert.equal(this.get("usernames"), "evil,trout");
      paste(element, "zip,zap,zoom");
      assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom");
      paste(element, "evil,abc,abc,abc");
      assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom,abc");

      this.set("usernames", "");
      paste(element, "names with spaces");
      assert.equal(this.get("usernames"), "names,with,spaces");

      this.set("usernames", null);
      paste(element, "@eviltrout,@codinghorror sam");
      assert.equal(this.get("usernames"), "eviltrout,codinghorror,sam");

      this.set("usernames", null);
      paste(element, "eviltrout\nsam\ncodinghorror");
      assert.equal(this.get("usernames"), "eviltrout,sam,codinghorror");
    },
  });

  componentTest("excluding usernames", {
    template: hbs`{{user-selector usernames=usernames excludedUsernames=excludedUsernames class="test-selector"}}`,

    beforeEach() {
      this.set("usernames", "mark");
      this.set("excludedUsernames", ["jeff", "sam", "robin"]);
    },

    test(assert) {
      let element = query(".test-selector");
      paste(element, "roman,penar,jeff,robin");
      assert.equal(this.get("usernames"), "mark,roman,penar");
    },
  });
});

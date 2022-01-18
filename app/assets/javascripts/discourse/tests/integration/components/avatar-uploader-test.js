import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  createFile,
  discourseModule,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("default", {
    template: hbs`{{avatar-uploader}}`,

    test(assert) {
      const inputElement = query(".hidden-upload-field");

      // simulate change event with custom files array
      const event = { target: { files: [createFile("avatar.png")] } };
      inputElement.testonchange(event);

      // if this point is reached then all before upload logic did not throw
      // any error
      assert.ok(true);
    },
  });
});

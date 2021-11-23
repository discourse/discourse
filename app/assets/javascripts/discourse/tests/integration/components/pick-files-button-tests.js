import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { triggerEvent } from "@ember/test-helpers";
import sinon from "sinon";
import bootbox from "bootbox";

function createBlob(mimeType, extension) {
  const blob = new Blob(["content"], {
    type: mimeType,
  });
  blob.name = `filename${extension}`;
  return blob;
}

discourseModule(
  "Integration | Component | pick-files-button",
  function (hooks) {
    const expectedExtension = ".json";
    const expectedMimeType = "text/json";

    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("acceptedFileTypes", [expectedExtension, expectedMimeType]);
      this.set("onFilesPicked", () => {});
    });

    componentTest("it doesn't show alert if a file has a supported MIME type", {
      skip: true,
      template: hbs`
        {{pick-files-button
          acceptedFileTypes=this.acceptedFileTypes
          onFilesPicked=this.onFilesPicked}}`,

      async test(assert) {
        sinon.stub(bootbox, "alert");

        const wrongExtension = ".txt";
        const file = createBlob(expectedMimeType, wrongExtension);

        await triggerEvent("input[type='file']", "change", { files: [file] });

        assert.ok(bootbox.alert.notCalled);
      },
    });

    componentTest("it doesn't show alert if a file has a supported extension", {
      skip: true,
      template: hbs`
        {{pick-files-button
          acceptedFileTypes=this.acceptedFileTypes
          onFilesPicked=this.onFilesPicked}}`,

      async test(assert) {
        sinon.stub(bootbox, "alert");

        const wrongMimeType = "text/plain";
        const file = createBlob(wrongMimeType, expectedExtension);

        await triggerEvent("input[type='file']", "change", { files: [file] });

        assert.ok(bootbox.alert.notCalled);
      },
    });

    componentTest(
      "it shows alert if a file has an unsupported extension and unsupported MIME type",
      {
        skip: true,
        template: hbs`
        {{pick-files-button
          acceptedFileTypes=this.acceptedFileTypes
          onFilesPicked=this.onFilesPicked}}`,

        async test(assert) {
          sinon.stub(bootbox, "alert");

          const wrongExtension = ".txt";
          const wrongMimeType = "text/plain";
          const file = createBlob(wrongMimeType, wrongExtension);

          await triggerEvent("input[type='file']", "change", { files: [file] });

          assert.ok(bootbox.alert.calledOnce);
        },
      }
    );
  }
);

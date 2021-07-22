import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { triggerEvent } from "@ember/test-helpers";
import sinon from "sinon";

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
    setupRenderingTest(hooks);

    componentTest(
      "it shows alert if a file with an unsupported extension was chosen",
      {
        skip: true,
        template: hbs`
        {{pick-files-button
          acceptedFileTypes=this.acceptedFileTypes
          onFilesChosen=this.onFilesChosen}}`,

        beforeEach() {
          const expectedExtension = ".json";
          this.set("acceptedFileTypes", [expectedExtension]);
          this.set("onFilesChosen", () => {});
        },

        async test(assert) {
          sinon.stub(bootbox, "alert");

          const wrongExtension = ".txt";
          const file = createBlob("text/json", wrongExtension);

          await triggerEvent("input#file-input", "change", { files: [file] });

          assert.ok(bootbox.alert.calledOnce);
        },
      }
    );

    componentTest(
      "it shows alert if a file with an unsupported MIME type was chosen",
      {
        skip: true,
        template: hbs`
        {{pick-files-button
          acceptedFileTypes=this.acceptedFileTypes
          onFilesChosen=this.onFilesChosen}}`,

        beforeEach() {
          const expectedMimeType = "text/json";
          this.set("acceptedFileTypes", [expectedMimeType]);
          this.set("onFilesChosen", () => {});
        },

        async test(assert) {
          sinon.stub(bootbox, "alert");

          const wrongMimeType = "text/plain";
          const file = createBlob(wrongMimeType, ".json");

          await triggerEvent("input#file-input", "change", { files: [file] });

          assert.ok(bootbox.alert.calledOnce);
        },
      }
    );
  }
);

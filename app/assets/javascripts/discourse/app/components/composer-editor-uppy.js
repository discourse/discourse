import ComposerEditor from "discourse/components/composer-editor";
import { alias } from "@ember/object/computed";
import ComposerUploadUppy from "discourse/mixins/composer-upload-uppy";

export default ComposerEditor.extend(ComposerUploadUppy, {
  layoutName: "components/composer-editor",
  fileUploadElementId: "file-uploader",
  eventPrefix: "composer",
  uploadType: "composer",
  uppyId: "composer-editor-uppy",
  composerModel: alias("composer"),
  composerModelContentKey: "reply",
  editorInputClass: ".d-editor-input",
});

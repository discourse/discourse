import ComposerEditor from "discourse/components/composer-editor";
import ComposerUploadUppy from "discourse/mixins/composer-upload-uppy";

export default ComposerEditor.extend(ComposerUploadUppy, {
  layoutName: "components/composer-editor",
});

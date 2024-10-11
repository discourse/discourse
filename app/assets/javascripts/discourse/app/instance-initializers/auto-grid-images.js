import { schedule } from "@ember/runloop";
import CodeblockButtons from "discourse/lib/codeblock-buttons";
import { withPluginApi } from "discourse/lib/plugin-api";
import { next } from "@ember/runloop";

export default {
  initialize(owner) {
    withPluginApi("1.37.2", (api) => {
      api.addComposerUploadMarkdownResolver(async (upload) => {
        // console.log("upload called");
        // TODO need alternate solution as uploads are separate and can't check simultaneous uploads...
      });

      // TODO get full list of supported image types
      // api.addComposerUploadHandler(["jpg", "jpeg", "png"], (files, editor) => {
      //   console.log(files, editor, files.length);
      //   return true;
      // files.forEach((file) => {
      //   // TODO seems to be preventing normal upload process despite return true :(
      //   return true;
      //   // console.log("Handling upload for", file.name, files, editor);
      // });
      // next(() => {
      //   console.log("next called");
      //   return true;
      // });
      // });
    });
  },
};

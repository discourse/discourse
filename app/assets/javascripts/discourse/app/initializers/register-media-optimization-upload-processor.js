import { addComposerUploadProcessor } from "discourse/components/composer-editor";

export default {
  name: "register-media-optimization-upload-processor",

  initialize(container) {
    let siteSettings = container.lookup("site-settings:main");
    if (siteSettings.composer_media_optimization_image_enabled) {
      addComposerUploadProcessor(
        { action: "optimizeJPEG" },
        {
          optimizeJPEG: (data, opts) =>
            container
              .lookup("service:media-optimization-worker")
              .optimizeImage(data, opts),
        }
      );
    }
  },
};

import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";

export default {
  name: "register-media-optimization-upload-processor",

  initialize(container) {
    let siteSettings = container.lookup("site-settings:main");
    if (siteSettings.composer_media_optimization_image_enabled) {
      addComposerUploadPreProcessor(
        UppyMediaOptimization,
        ({ isMobileDevice }) => {
          return {
            optimizeFn: (data, opts) =>
              container
                .lookup("service:media-optimization-worker")
                .optimizeImage(data, opts),
            runParallel: !isMobileDevice,
          };
        }
      );
    }
  },
};

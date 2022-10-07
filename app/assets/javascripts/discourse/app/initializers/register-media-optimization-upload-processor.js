import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { Promise } from "rsvp";

export default {
  name: "register-media-optimization-upload-processor",

  initialize(container) {
    let siteSettings = container.lookup("service:site-settings");
    if (siteSettings.composer_media_optimization_image_enabled) {
      addComposerUploadPreProcessor(
        UppyMediaOptimization,
        ({ isMobileDevice }) => {
          return {
            optimizeFn: (data, opts) => {
              if (container.isDestroyed || container.isDestroying) {
                return Promise.resolve();
              }

              return container
                .lookup("service:media-optimization-worker")
                .optimizeImage(data, opts);
            },
            runParallel: !isMobileDevice,
          };
        }
      );
    }
  },
};

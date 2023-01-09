import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";
import { Promise } from "rsvp";

export default {
  name: "register-media-optimization-upload-processor",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const capabilities = container.lookup("capabilities:main");

    if (siteSettings.composer_media_optimization_image_enabled) {
      // NOTE: There are various performance issues with the Canvas
      // in iOS Safari that are causing crashes when processing images
      // with spikes of over 100% CPU usage. The cause of this is unknown,
      // but profiling points to CanvasRenderingContext2D.getImageData()
      // and CanvasRenderingContext2D.drawImage().
      //
      // Until Safari makes some progress with OffscreenCanvas or other
      // alternatives we cannot support this workflow.
      //
      // TODO (martin): Revisit around 2022-06-01 to see the state of iOS Safari.
      if (
        capabilities.isIOS &&
        !siteSettings.composer_ios_media_optimisation_image_enabled
      ) {
        return;
      }

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

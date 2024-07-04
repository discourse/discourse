import { Promise } from "rsvp";
import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    const capabilities = owner.lookup("service:capabilities");

    if (siteSettings.composer_media_optimization_image_enabled) {
      // NOTE: There are various performance issues with the Canvas
      // in iOS Safari that are causing crashes when processing images
      // with spikes of over 100% CPU usage. The cause of this is unknown,
      // but profiling points to CanvasRenderingContext2D.getImageData()
      // and CanvasRenderingContext2D.drawImage().
      //
      // Until Safari makes some progress with OffscreenCanvas or other
      // alternatives we cannot support this workflow.
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
              if (owner.isDestroyed || owner.isDestroying) {
                return Promise.resolve();
              }

              return owner
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

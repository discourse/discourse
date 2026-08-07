import { Promise } from "rsvp";
import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";

// Devices stuck on EOL iOS versions are older hardware where WebKit's memory
// watchdog kills (and reloads) the page during WASM image processing instead
// of raising a catchable error, so skip optimization there entirely.
// https://endoflife.date/iphone
export const MAX_EOL_IOS_MAJOR_VERSION = 18;

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    const capabilities = owner.lookup("service:capabilities");

    if (siteSettings.composer_media_optimization_image_enabled) {
      if (
        capabilities.isIOS &&
        (!siteSettings.composer_ios_media_optimisation_image_enabled ||
          (capabilities.iosMajorVersion &&
            capabilities.iosMajorVersion <= MAX_EOL_IOS_MAJOR_VERSION))
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

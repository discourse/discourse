import { lookup } from "discourse/lib/service";
import { Promise } from "rsvp";
import { addComposerUploadPreProcessor } from "discourse/lib/plugin-registries/composer-uploads";
import SiteSettingsService from "discourse/services/site-settings";
import CapabilitiesService from "discourse/services/capabilities";

// Devices stuck on EOL iOS versions are older hardware where WebKit's memory
// watchdog kills (and reloads) the page during WASM image processing instead
// of raising a catchable error, so skip optimization there entirely.
// https://endoflife.date/iphone
export const MAX_EOL_IOS_MAJOR_VERSION = 18;

export default {
  initialize(owner) {
    const siteSettings = lookup(owner, SiteSettingsService);
    const capabilities = lookup(owner, CapabilitiesService);

    if (siteSettings.composer_media_optimization_image_enabled) {
      if (
        capabilities.isIOS &&
        (!siteSettings.composer_ios_media_optimisation_image_enabled ||
          (capabilities.iosMajorVersion &&
            capabilities.iosMajorVersion <= MAX_EOL_IOS_MAJOR_VERSION))
      ) {
        return;
      }

      // The composer loads on demand too, so the plugin is registered well before it is used.
      import("discourse/lib/uppy-media-optimization-plugin").then(
        ({ default: UppyMediaOptimization }) =>
          addComposerUploadPreProcessor(
            UppyMediaOptimization,
            ({ isMobileDevice }) => {
              return {
                optimizeFn: (data, opts) => {
                  if (owner.isDestroying) {
                    return Promise.resolve();
                  }

                  return owner
                    .lookup("service:media-optimization-worker")
                    .optimizeImage(data, opts);
                },
                runParallel: !isMobileDevice,
              };
            }
          )
      );
    }
  },
};

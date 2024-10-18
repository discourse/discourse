import { Promise } from "rsvp";
import { addComposerUploadPreProcessor } from "discourse/components/composer-editor";
import UppyMediaOptimization from "discourse/lib/uppy-media-optimization-plugin";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");
    const capabilities = owner.lookup("service:capabilities");

    if (siteSettings.composer_media_optimization_image_enabled) {
      if (
        capabilities.isIOS &&
        !siteSettings.composer_ios_media_optimisation_image_enabled
      ) {
        return;
      }

      // Restrict feature to browsers that support OffscreenCanvas
      if (typeof OffscreenCanvas === "undefined") {
        return;
      }
      if (!("createImageBitmap" in self)) {
        return;
      }

      // prior to v18, Safari has WASM memory growth bugs
      // using `document.startViewTransition` as a proxy for Safari 18+
      // eg https://github.com/emscripten-core/emscripten/issues/19144
      if (capabilities.isSafari && document.startViewTransition === undefined) {
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

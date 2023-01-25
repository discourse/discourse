import Mixin from "@ember/object/mixin";
import { warn } from "@ember/debug";

export default Mixin.create({
  _consoleDebug(msg) {
    if (this.siteSettings.enable_upload_debug_mode) {
      // eslint-disable-next-line no-console
      console.log(msg);
    }
  },

  _consolePerformanceTiming(timing) {
    const minutes = Math.floor(timing.duration / 60000);
    const seconds = ((timing.duration % 60000) / 1000).toFixed(0);
    const duration = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    this._consoleDebug(
      `${timing.name}:\n duration: ${duration} (${timing.duration}ms)`
    );
  },

  _performanceApiSupport() {
    performance.mark("testing support 1");
    performance.mark("testing support 2");
    const perfMeasure = performance.measure(
      "performance api support",
      "testing support 1",
      "testing support 2"
    );
    return perfMeasure;
  },

  _instrumentUploadTimings() {
    if (!this._performanceApiSupport()) {
      warn(
        "Some browsers do not return a PerformanceMeasure when calling performance.mark, disabling instrumentation. See https://developer.mozilla.org/en-US/docs/Web/API/Performance/measure#return_value and https://bugzilla.mozilla.org/show_bug.cgi?id=1724645",
        { id: "discourse.upload-debugging" }
      );
      return;
    }

    this._uppyInstance.on("upload", (data) => {
      data.fileIDs.forEach((fileId) =>
        performance.mark(`upload-${fileId}-start`)
      );
    });

    this._uppyInstance.on("create-multipart", (fileId) => {
      performance.mark(`upload-${fileId}-create-multipart`);
    });

    this._uppyInstance.on("create-multipart-success", (fileId) => {
      performance.mark(`upload-${fileId}-create-multipart-success`);
    });

    this._uppyInstance.on("complete-multipart", (fileId) => {
      performance.mark(`upload-${fileId}-complete-multipart`);

      this._consolePerformanceTiming(
        performance.measure(
          `upload-${fileId}-multipart-all-parts-complete`,
          `upload-${fileId}-create-multipart-success`,
          `upload-${fileId}-complete-multipart`
        )
      );
    });

    this._uppyInstance.on("complete-multipart-success", (fileId) => {
      performance.mark(`upload-${fileId}-complete-multipart-success`);

      this._consolePerformanceTiming(
        performance.measure(
          `upload-${fileId}-multipart-total-network-exclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart`
        )
      );

      this._consolePerformanceTiming(
        performance.measure(
          `upload-${fileId}-multipart-total-network-inclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );

      this._consolePerformanceTiming(
        performance.measure(
          `upload-${fileId}-multipart-complete-convert-to-upload`,
          `upload-${fileId}-complete-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );
    });

    this._uppyInstance.on("upload-success", (file) => {
      performance.mark(`upload-${file.id}-end`);
      this._consolePerformanceTiming(
        performance.measure(
          `upload-${file.id}-multipart-total-inclusive-preprocessing`,
          `upload-${file.id}-start`,
          `upload-${file.id}-end`
        )
      );
    });
  },
});

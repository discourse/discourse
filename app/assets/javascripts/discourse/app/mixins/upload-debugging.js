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
    // Sometimes performance.measure can fail to return a PerformanceMeasure
    // object, in this case we can't log anything so return to prevent errors.
    if (!timing) {
      return;
    }

    const minutes = Math.floor(timing.duration / 60000);
    const seconds = ((timing.duration % 60000) / 1000).toFixed(0);
    const duration = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    this._consoleDebug(
      `${timing.name}:\n duration: ${duration} (${timing.duration}ms)`
    );
  },

  _performanceApiSupport() {
    this._performanceMark("testing support 1");
    this._performanceMark("testing support 2");
    const perfMeasure = this._performanceMeasure(
      "performance api support",
      "testing support 1",
      "testing support 2"
    );
    return perfMeasure;
  },

  _performanceMark(markName) {
    return performance.mark(markName);
  },

  _performanceMeasure(measureName, startMark, endMark) {
    let measureResult;
    try {
      measureResult = performance.measure(measureName, startMark, endMark);
    } catch (error) {
      if (
        error.message.includes("Failed to execute 'measure' on 'Performance'")
      ) {
        // eslint-disable-next-line no-console
        console.warn(
          `Uppy performance measure failed: ${measureName}, ${startMark}, ${endMark}`
        );
      }
    }
    return measureResult;
  },

  _instrumentUploadTimings() {
    if (!this._performanceApiSupport()) {
      warn(
        "Some browsers do not return a PerformanceMeasure when calling this._performanceMark, disabling instrumentation. See https://developer.mozilla.org/en-US/docs/Web/API/this._performanceMeasure#return_value and https://bugzilla.mozilla.org/show_bug.cgi?id=1724645",
        { id: "discourse.upload-debugging" }
      );
      return;
    }

    this._uppyInstance.on("upload", (data) => {
      data.fileIDs.forEach((fileId) =>
        this._performanceMark(`upload-${fileId}-start`)
      );
    });

    this._uppyInstance.on("create-multipart", (fileId) => {
      this._performanceMark(`upload-${fileId}-create-multipart`);
    });

    this._uppyInstance.on("create-multipart-success", (fileId) => {
      this._performanceMark(`upload-${fileId}-create-multipart-success`);
    });

    this._uppyInstance.on("complete-multipart", (fileId) => {
      this._performanceMark(`upload-${fileId}-complete-multipart`);

      this._consolePerformanceTiming(
        this._performanceMeasure(
          `upload-${fileId}-multipart-all-parts-complete`,
          `upload-${fileId}-create-multipart-success`,
          `upload-${fileId}-complete-multipart`
        )
      );
    });

    this._uppyInstance.on("complete-multipart-success", (fileId) => {
      this._performanceMark(`upload-${fileId}-complete-multipart-success`);

      this._consolePerformanceTiming(
        this._performanceMeasure(
          `upload-${fileId}-multipart-total-network-exclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart`
        )
      );

      this._consolePerformanceTiming(
        this._performanceMeasure(
          `upload-${fileId}-multipart-total-network-inclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );

      this._consolePerformanceTiming(
        this._performanceMeasure(
          `upload-${fileId}-multipart-complete-convert-to-upload`,
          `upload-${fileId}-complete-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );
    });

    this._uppyInstance.on("upload-success", (file) => {
      this._performanceMark(`upload-${file.id}-end`);
      this._consolePerformanceTiming(
        this._performanceMeasure(
          `upload-${file.id}-multipart-total-inclusive-preprocessing`,
          `upload-${file.id}-start`,
          `upload-${file.id}-end`
        )
      );
    });
  },
});

import { warn } from "@ember/debug";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";

export default class UppyUploadDebugging {
  @service siteSettings;

  constructor(owner) {
    setOwner(this, owner);
  }

  log(msg) {
    if (this.siteSettings.enable_upload_debug_mode) {
      // eslint-disable-next-line no-console
      console.log(msg);
    }
  }

  #consolePerformanceTiming(timing) {
    // Sometimes performance.measure can fail to return a PerformanceMeasure
    // object, in this case we can't log anything so return to prevent errors.
    if (!timing) {
      return;
    }

    const minutes = Math.floor(timing.duration / 60000);
    const seconds = ((timing.duration % 60000) / 1000).toFixed(0);
    const duration = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    this.log(`${timing.name}:\n duration: ${duration} (${timing.duration}ms)`);
  }

  #performanceApiSupport() {
    this.#performanceMark("testing support 1");
    this.#performanceMark("testing support 2");
    const perfMeasure = this.#performanceMeasure(
      "performance api support",
      "testing support 1",
      "testing support 2"
    );
    return perfMeasure;
  }

  #performanceMark(markName) {
    return performance.mark(markName);
  }

  #performanceMeasure(measureName, startMark, endMark) {
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
  }

  instrumentUploadTimings(uppy) {
    if (!this.#performanceApiSupport()) {
      warn(
        "Some browsers do not return a PerformanceMeasure when calling this.#performanceMark, disabling instrumentation. See https://developer.mozilla.org/en-US/docs/Web/API/Performance/measure#return_value and https://bugzilla.mozilla.org/show_bug.cgi?id=1724645",
        { id: "discourse.upload-debugging" }
      );
      return;
    }

    uppy.on("upload", (data) => {
      data.fileIDs.forEach((fileId) =>
        this.#performanceMark(`upload-${fileId}-start`)
      );
    });

    uppy.on("create-multipart", (fileId) => {
      this.#performanceMark(`upload-${fileId}-create-multipart`);
    });

    uppy.on("create-multipart-success", (fileId) => {
      this.#performanceMark(`upload-${fileId}-create-multipart-success`);
    });

    uppy.on("complete-multipart", (fileId) => {
      this.#performanceMark(`upload-${fileId}-complete-multipart`);

      this.#consolePerformanceTiming(
        this.#performanceMeasure(
          `upload-${fileId}-multipart-all-parts-complete`,
          `upload-${fileId}-create-multipart-success`,
          `upload-${fileId}-complete-multipart`
        )
      );
    });

    uppy.on("complete-multipart-success", (fileId) => {
      this.#performanceMark(`upload-${fileId}-complete-multipart-success`);

      this.#consolePerformanceTiming(
        this.#performanceMeasure(
          `upload-${fileId}-multipart-total-network-exclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart`
        )
      );

      this.#consolePerformanceTiming(
        this.#performanceMeasure(
          `upload-${fileId}-multipart-total-network-inclusive-complete-multipart`,
          `upload-${fileId}-create-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );

      this.#consolePerformanceTiming(
        this.#performanceMeasure(
          `upload-${fileId}-multipart-complete-convert-to-upload`,
          `upload-${fileId}-complete-multipart`,
          `upload-${fileId}-complete-multipart-success`
        )
      );
    });

    uppy.on("upload-success", (file) => {
      this.#performanceMark(`upload-${file.id}-end`);
      this.#consolePerformanceTiming(
        this.#performanceMeasure(
          `upload-${file.id}-multipart-total-inclusive-preprocessing`,
          `upload-${file.id}-start`,
          `upload-${file.id}-end`
        )
      );
    });
  }
}

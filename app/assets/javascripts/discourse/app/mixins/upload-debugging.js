import Mixin from "@ember/object/mixin";

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

  _instrumentUploadTimings() {
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

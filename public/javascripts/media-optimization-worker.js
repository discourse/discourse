// The media optimization bundle uses webpack's import-scripts chunk loader,
// so worker-only dynamic chunks can be loaded without a DOM shim.
onmessage = async function (e) {
  switch (e.data.type) {
    case "compress":
      try {
        globalThis.debugMode = e.data.settings.debug_mode;

        let optimized = await globalThis.optimize(
          e.data.file,
          e.data.fileName,
          e.data.width,
          e.data.height,
          e.data.originalFileSize,
          e.data.settings
        );
        postMessage(
          {
            type: "file",
            file: optimized,
            fileName: e.data.fileName,
            fileId: e.data.fileId,
          },
          [optimized]
        );
      } catch (error) {
        console.error(error);
        postMessage({
          type: "error",
          file: e.data.file,
          fileName: e.data.fileName,
          fileId: e.data.fileId,
        });
      }
      break;
    case "convert":
      try {
        globalThis.debugMode = e.data.settings.debug_mode;

        let converted = await globalThis.convert(
          e.data.file,
          e.data.fileName,
          e.data.fileType,
          e.data.originalFileSize,
          e.data.settings
        );
        postMessage(
          {
            type: "file",
            file: converted.data,
            fileName: e.data.fileName,
            fileId: e.data.fileId,
            outputType: converted.outputType,
          },
          [converted.data]
        );
      } catch (error) {
        console.error(error);
        postMessage({
          type: "error",
          file: e.data.file,
          fileName: e.data.fileName,
          fileId: e.data.fileId,
        });
      }
      break;
    case "convertAnimated":
      try {
        globalThis.debugMode = e.data.settings.debug_mode;

        let animatedResult = await globalThis.convertAnimated(
          e.data.file,
          e.data.fileName,
          e.data.originalFileSize,
          e.data.settings
        );
        if (animatedResult) {
          postMessage(
            {
              type: "file",
              file: animatedResult.data,
              fileName: e.data.fileName,
              fileId: e.data.fileId,
              outputType: animatedResult.outputType,
            },
            [animatedResult.data]
          );
        } else {
          postMessage({
            type: "skipped",
            fileName: e.data.fileName,
            fileId: e.data.fileId,
          });
        }
      } catch (error) {
        console.error(error);
        postMessage({
          type: "error",
          file: e.data.file,
          fileName: e.data.fileName,
          fileId: e.data.fileId,
        });
      }
      break;
    case "install":
      try {
        await loadLibs(e.data.settings);
        postMessage({ type: "installed" });
      } catch (error) {
        console.error(error);
        postMessage({ type: "installFailed", errorMessage: error.message });
      }
      break;
    default:
      logIfDebug(`Sorry, we are out of ${e}.`);
  }
};

async function loadLibs(settings) {
  importScripts(settings.mediaOptimizationBundle);
}

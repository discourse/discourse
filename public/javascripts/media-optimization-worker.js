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
    case "install":
      try {
        globalThis.document = {}; // webpack expects this to exist
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

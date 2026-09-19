// Built by rolldown as a standalone chunk and started as a module worker via a
// blob bootstrap (see the media-optimization-worker service), so it inherits the
// host document CSP. The codecs are bundled straight into this chunk.
import { convert, convertAnimated } from "./codecs.js";

self.onmessage = async function (e) {
  switch (e.data.type) {
    case "convert":
      try {
        globalThis.debugMode = e.data.settings.debug_mode;

        let converted = await convert(
          e.data.file,
          e.data.fileName,
          e.data.fileType,
          e.data.originalFileSize,
          e.data.settings
        );
        if (converted) {
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
        } else {
          postMessage({
            type: "skipped",
            fileName: e.data.fileName,
            fileId: e.data.fileId,
          });
        }
      } catch (error) {
        // eslint-disable-next-line no-console
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

        let animatedResult = await convertAnimated(
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
        // eslint-disable-next-line no-console
        console.error(error);
        postMessage({
          type: "error",
          file: e.data.file,
          fileName: e.data.fileName,
          fileId: e.data.fileId,
        });
      }
      break;
    default:
      // eslint-disable-next-line no-console
      console.error(`Unexpected message type: ${e.data.type}`);
  }
};

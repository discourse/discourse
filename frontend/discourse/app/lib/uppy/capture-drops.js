/**
 * Handles files dropped on `target` until the returned function is called or
 * `signal` aborts. Without it, a drop that arrives before the upload runtime
 * installs its own drop handling makes the browser open the file.
 *
 * @param {HTMLElement} target
 * @param {(files: File[]) => void} onFiles
 * @param {AbortSignal} signal
 * @returns {() => void} stops capturing
 */
export default function captureDrops(target, onFiles, signal) {
  const capture = new AbortController();
  signal.addEventListener("abort", () => capture.abort(), { once: true });

  target.addEventListener(
    "dragover",
    (event) => {
      if (event.dataTransfer?.types.includes("Files")) {
        event.preventDefault();
      }
    },
    { signal: capture.signal }
  );

  target.addEventListener(
    "drop",
    (event) => {
      const files = [...(event.dataTransfer?.files ?? [])];
      if (files.length) {
        event.preventDefault();
        onFiles(files);
      }
    },
    { signal: capture.signal }
  );

  return () => capture.abort();
}

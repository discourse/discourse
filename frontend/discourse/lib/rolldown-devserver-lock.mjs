import * as fs from "fs";

export const MANIFEST_DIR = "./dist/manifest";
export const BUILD_STATUS_FILE = `${MANIFEST_DIR}/build.json`;

function isProcessRunning(pid) {
  try {
    // Signal 0 checks whether the process exists without sending a signal.
    process.kill(pid, 0);
    return true;
  } catch (e) {
    // ESRCH means nothing owns the pid (a stale status file). EPERM means it's
    // owned by another user, i.e. still running.
    return e.code !== "ESRCH";
  }
}

export function exitIfDevServerRunning() {
  let existing;
  try {
    existing = JSON.parse(fs.readFileSync(BUILD_STATUS_FILE, "utf8"));
  } catch {
    return;
  }

  const { pid } = existing;
  if (pid && isProcessRunning(pid)) {
    // eslint-disable-next-line no-console
    console.error(
      `rolldown devserver is already running on pid=${pid}. Stop it before ` +
        `starting another build, or delete ${BUILD_STATUS_FILE} if it's stale.`
    );
    process.exit(1);
  }
}

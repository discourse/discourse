import {
  authorizedExtensions,
  authorizesAllExtensions,
} from "discourse/lib/uploads";
import { safeTransferFilename } from "./file-transfer-ui.js";

export const MEBIBYTE = 1024 * 1024;
export const DEFAULT_MAX_FILE_SIZE = 100 * MEBIBYTE;
export const MAX_CONFIGURED_FILE_SIZE = 102400 * MEBIBYTE;

// The conventional _mb setting name represents binary MiB, not decimal MB.
export function fileTransferMaxSize(mebibytes) {
  if (!Number.isSafeInteger(mebibytes) || mebibytes < 1 || mebibytes > 102400) {
    return DEFAULT_MAX_FILE_SIZE;
  }
  return mebibytes * MEBIBYTE;
}

// Mirrors upload authorization: `staff` is the sender's staff status, because
// the sender's extension list applies on both ends of a transfer. Checks the
// name the receiver will save, not the one on the wire.
export function isAuthorizedFileName(name, staff, siteSettings) {
  if (authorizesAllExtensions(staff, siteSettings)) {
    return true;
  }
  name = safeTransferFilename(name);
  const dot = name.lastIndexOf(".");
  if (dot === -1) {
    return false;
  }
  return authorizedExtensions(staff, siteSettings).includes(
    name.slice(dot + 1).toLowerCase()
  );
}

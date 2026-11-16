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

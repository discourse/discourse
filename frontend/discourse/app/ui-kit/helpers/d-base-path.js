/* eslint-disable local/require-ts-check */
import getUrl from "discourse/lib/get-url";

export default function dBasePath() {
  return getUrl("");
}

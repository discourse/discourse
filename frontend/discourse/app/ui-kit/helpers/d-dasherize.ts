import { dasherize as emberDasherize } from "@ember/string";

/**
 * Dasherizes a value after turning its first dot into a dash.
 *
 * @param value - The value to dasherize. A missing value counts as empty.
 * @returns The dasherized value.
 */
export default function dDasherize(value = ""): string {
  return emberDasherize(value.replace(".", "-"));
}

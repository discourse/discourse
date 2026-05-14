/* eslint-disable local/require-ts-check */
import { dasherize as emberDasherize } from "@ember/string";

export default function dDasherize(value = "") {
  return emberDasherize(value.replace(".", "-"));
}

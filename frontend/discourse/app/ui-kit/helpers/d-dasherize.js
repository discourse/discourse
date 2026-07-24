import { dasherize as emberDasherize } from "@ember/string";

export default function dDasherize(value = "") {
  return emberDasherize(value.replace(".", "-"));
}

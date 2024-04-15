import { dasherize as emberDasherize } from "@ember/string";

export default function dasherize(value = "") {
  return emberDasherize(value.replace(".", "-"));
}

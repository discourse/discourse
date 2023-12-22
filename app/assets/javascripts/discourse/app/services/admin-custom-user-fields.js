import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class AdminCustomUserFields extends Service {
  @tracked additionalProperties = [];

  addProperties(properties) {
    if (typeof properties === "string") {
      properties = [properties];
    }
    this.additionalProperties.push(...properties);
  }
}

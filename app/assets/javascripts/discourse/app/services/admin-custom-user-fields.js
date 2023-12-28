import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class AdminCustomUserFields extends Service {
  @tracked additionalProperties = [];

  addProperty(property) {
    this.additionalProperties.push(property);
  }
}

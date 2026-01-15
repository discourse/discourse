import RestModel from "discourse/models/rest";

export default class Channel extends RestModel {
  updateProperties() {
    return this.getProperties(["data"]);
  }

  createProperties() {
    return this.getProperties(["provider", "data"]);
  }
}

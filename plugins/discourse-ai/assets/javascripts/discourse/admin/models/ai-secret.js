import RestModel from "discourse/models/rest";

export default class AiSecret extends RestModel {
  createProperties() {
    return this.getProperties("id", "name", "secret");
  }

  updateProperties() {
    const attrs = this.createProperties();
    attrs.id = this.id;
    return attrs;
  }
}

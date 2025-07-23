import RestModel from "discourse/models/rest";

export default class AiFeature extends RestModel {
  createProperties() {
    return this.getProperties("id", "module", "global_enabled", "features");
  }
}

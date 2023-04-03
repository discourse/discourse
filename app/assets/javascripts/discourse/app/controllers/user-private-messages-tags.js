import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

export default class extends Controller {
  @tracked tagName = null;
}

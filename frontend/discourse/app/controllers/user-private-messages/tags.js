import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class extends Controller {
  /** @type {string | null} */
  @tracked tagName = null;
}

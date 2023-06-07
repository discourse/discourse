import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";

export default class ModalController extends Controller {
  @tracked hidden = true;
}

import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class GroupActivityTopicsController extends Controller {
  @action
  loadMore() {
    this.model.loadMore();
  }
}

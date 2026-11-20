import Controller from "@ember/controller";
import { action } from "@ember/object";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class LiveRoomsIndexController extends Controller {
  @action
  destroyRoom(room) {
    removeValueFromArray(this.model.content, room);
  }
}

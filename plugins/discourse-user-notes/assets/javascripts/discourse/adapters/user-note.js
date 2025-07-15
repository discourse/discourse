import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default class UserNote extends RestAdapter {
  destroyRecord(store, type, record) {
    const path = this.pathFor(store, type, record.id);
    return ajax(`${path}?user_id=${record.user_id}`, { method: "DELETE" });
  }
}

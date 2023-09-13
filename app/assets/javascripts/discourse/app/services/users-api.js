import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class UsersApiService extends Service {
  @service store;

  async lookupUsers(usernames) {
    const response = await ajax(`/u/lookup/users.json`, {
      data: { usernames },
    });
    return response.users.map((u) => this.store.createRecord("user", u));
  }
}

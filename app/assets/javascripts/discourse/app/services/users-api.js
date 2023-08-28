import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import User from "discourse/models/user";

export default class UsersApiService extends Service {
  async lookupUsers(usernames) {
    const response = await ajax(`/u/lookup/users.json`, {
      data: { usernames },
    });
    return response.users.map((u) => User.create(u));
  }
}

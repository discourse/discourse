import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";

function normalizeAbout(result) {
  const users = Object.fromEntries(
    (result.users ?? []).map((user) => [user.id, user])
  );
  const yearAgo = moment().utc().subtract(1, "year");
  const recentlySeen = (ids = []) =>
    ids
      .map((id) => users[id])
      .filter((user) => user && moment(user.last_seen_at) > yearAgo);

  result.about.admins = recentlySeen(result.about.admin_ids);
  result.about.moderators = recentlySeen(result.about.moderator_ids);
  result.about.category_moderators?.forEach((entry) => {
    entry.moderators = entry.moderator_ids.map((id) => users[id]);
  });

  return result;
}

export default class About extends Service {
  @tracked data;

  #request;

  load({ refresh = false } = {}) {
    if (this.data && !refresh) {
      return Promise.resolve(this.data);
    }

    this.#request ??= ajax("/about.json")
      .then(normalizeAbout)
      .then((data) => {
        this.data = data;
        return data;
      })
      .finally(() => {
        this.#request = null;
      });

    return this.#request;
  }
}

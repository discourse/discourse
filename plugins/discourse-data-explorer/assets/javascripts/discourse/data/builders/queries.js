import { readMany } from "discourse/data/builders/helpers";

const SORT_FIELDS = {
  name: "name",
  username: "user.username",
  last_run_at: "lastRunAt",
};

export function findQueries({ search, tags, sort, descending }) {
  const params = new URLSearchParams({
    include: "user,groups",
    sort: `${descending ? "-" : ""}${SORT_FIELDS[sort]}`,
  });
  if (search) {
    params.set("filter[search]", search);
  }
  if (tags) {
    tags.split(",").forEach((tag) => params.append("filter[tag][]", tag));
  }

  return readMany(`/api/data-explorer/queries?${params}`);
}

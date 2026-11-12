import { filterEmpty, query } from "discourse/data/builders/json-api";

const SORT_FIELDS = {
  name: "name",
  username: "user.username",
  last_run_at: "lastRunAt",
};

export function findQueries({ search, tags, sort, descending }) {
  return query(
    "queries",
    filterEmpty({
      include: ["user", "groups"],
      sort: `${descending ? "-" : ""}${SORT_FIELDS[sort]}`,
      "filter[search]": search,
      "filter[tag]": tags,
    }),
    { namespace: "api/data-explorer" }
  );
}

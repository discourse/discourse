// The assign-queue counterpart of core's addDiscoveryQueryParam, which the
// queues cannot use because they are not discovery lists. Plugins add route
// queryParams definitions to the "assigned-list-query-params" value
// transformer; they must not override order, ascending, search, direct, or
// exclude_category_ids, which the queues manage themselves.
import { isEmpty } from "@ember/utils";
import { applyValueTransformer } from "discourse/lib/transformer";

export function assignedListQueryParams() {
  return applyValueTransformer("assigned-list-query-params", {});
}

// Merges the extension params held by source (a route's model params or the
// queue controller) onto baseParams. Cleared values are dropped, since the
// user queue's base spreads the previous request's params.
export function assignedListRequestParams(source, baseParams = {}) {
  const params = { ...baseParams };
  for (const name of Object.keys(assignedListQueryParams())) {
    if (isEmpty(source[name])) {
      delete params[name];
    } else {
      params[name] = source[name];
    }
  }
  return params;
}

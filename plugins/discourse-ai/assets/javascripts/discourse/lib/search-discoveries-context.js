import { searchTermScopesToPMs } from "discourse/lib/search";

// Mirrors SearchMenu#searchContext and #isPMOnly: only topic and PM contexts
// (whether from the UI or an `in:` filter in the term) actually scope the
// search request. Category and tag pages set search.searchContext but the menu
// still searches globally there, so discoveries should still trigger.
export function isScopedSearch(search) {
  if (!search) {
    return false;
  }

  return (
    search.inTopicContext ||
    search.searchContext?.type === "private_messages" ||
    searchTermScopesToPMs(search.activeGlobalSearchTerm)
  );
}

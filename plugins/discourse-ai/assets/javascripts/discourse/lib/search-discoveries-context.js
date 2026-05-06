// Mirrors SearchMenu#searchContext: only topic and PM contexts actually scope
// the search request. Category and tag pages set search.searchContext but the
// menu still searches globally there, so discoveries should still trigger.
export function isScopedSearch(search) {
  return (
    search?.inTopicContext || search?.searchContext?.type === "private_messages"
  );
}

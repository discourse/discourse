import { searchForTerm } from "discourse/lib/search";
import Topic from "discourse/models/topic";
import type { TopicPickerArchetype } from "discourse/ui-kit/select/recipes/topics/-internals/topic-texts";
import type {
  SelectItem,
  SelectItemId,
} from "discourse/ui-kit/select/select-engine";

/**
 * Searches topics as the topic chooser always has: nothing without a term or filters; with a
 * term, titles, a pasted URL or an id, restricted to the archetype when one is given. The topic
 * models are the select's items, as both lookups answer them.
 */
export async function searchTopics(
  filter: string,
  {
    additionalFilters = "",
    archetype,
  }: {
    /** Search filters added to every query, such as `status:public`. */
    additionalFilters?: string;
    /** The archetype searched; `null` searches every topic the term finds. */
    archetype?: TopicPickerArchetype | null;
  }
): Promise<SelectItem[]> {
  if (!filter && !additionalFilters) {
    return [];
  }

  const params = filter
    ? {
        typeFilter:
          archetype === "private_message" ? "private_messages" : "topic",
        restrictToArchetype: archetype ?? undefined,
        searchForId: true,
      }
    : {};
  const results = (await searchForTerm(
    `${filter} ${additionalFilters}`,
    params
  )) as { posts?: { topic: Topic }[] } | undefined;
  return (results?.posts?.map((post) => post.topic) ??
    []) as unknown as SelectItem[];
}

/** Looks the held topic ids up together; an id that is not a number never reaches the server. */
export async function findHeldTopics(
  values: SelectItemId[]
): Promise<SelectItem[]> {
  const ids = values.map(Number).filter(Number.isInteger);
  return (await Topic.findByIds(ids)) as unknown as SelectItem[];
}

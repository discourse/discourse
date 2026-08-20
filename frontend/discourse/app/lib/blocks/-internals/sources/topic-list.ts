import type Owner from "@ember/owner";
import { defineBlockDataSource } from "discourse/blocks";
import { fetchTopicList } from "discourse/lib/blocks/-internals/fetch-topic-list";
import type User from "discourse/models/user";
import type Store from "discourse/services/store";

/**
 * Describes a topic list independently of the block that requested it.
 * Identical descriptors share the source's cache key across block types.
 */
interface TopicListDescriptor {
  kind: "topic-list";
  filter: string;
  categoryId?: number;
  tag?: string;
  solved?: boolean;
  count: number;
}

/**
 * Resolves topic-list descriptors through the shared topic-list fetcher.
 *
 * The stable source name allows different topic-list blocks to deduplicate
 * identical requests while retaining their own request and skeleton functions.
 */
export const topicListDataSource = defineBlockDataSource({
  name: "topic-list",
  resolve(descriptor: TopicListDescriptor, { owner }: { owner: Owner }) {
    return fetchTopicList({
      store: owner.lookup("service:store") as Store,
      currentUser: owner.lookup("service:current-user") as User | null,
      filterType: descriptor.filter,
      categoryId: descriptor.categoryId,
      tag: descriptor.tag,
      solved: descriptor.solved,
      count: descriptor.count,
    });
  },
});

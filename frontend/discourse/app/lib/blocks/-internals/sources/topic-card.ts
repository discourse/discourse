import type Owner from "@ember/owner";
import { defineBlockDataSource } from "discourse/blocks";
import {
  fetchTopicCards,
  type TopicCardData,
} from "discourse/lib/blocks/-internals/fetch-topic-cards";
import type Site from "discourse/models/site";

/**
 * Describes one hand-picked topic independently of the block that requested it.
 * Identical descriptors share the source's cache key across block types.
 */
interface TopicCardDescriptor {
  kind: "topic-card";

  /** The configured topic, or `undefined` while the block is unconfigured. */
  topicId?: number;
}

/** The combined request built from a window of descriptors. */
interface TopicCardBatchRequest {
  topicIds: number[];
}

/**
 * Resolves hand-picked topic cards, batching every card resolved in the same
 * render pass into a single list request. A page of curated cards therefore
 * costs one request rather than one per card.
 *
 * The stable source name lets different card-shaped blocks deduplicate requests
 * for the same topic while keeping their own request functions.
 */
export const topicCardDataSource = defineBlockDataSource({
  name: "topic-card",
  batch: {
    request(descriptors: readonly TopicCardDescriptor[]) {
      // An unconfigured card contributes no id; deduplicate the rest, since two
      // scopes can enqueue the same topic into one window.
      const topicIds = [
        ...new Set(
          descriptors
            .map((descriptor) => descriptor.topicId)
            .filter((topicId): topicId is number => !!topicId)
        ),
      ];

      return { topicIds };
    },

    resolve(
      request: TopicCardBatchRequest,
      { owner, signal }: { owner: Owner; signal?: AbortSignal }
    ) {
      if (!request.topicIds.length) {
        return Promise.resolve(new Map<number, TopicCardData>());
      }

      return fetchTopicCards({
        topicIds: request.topicIds,
        site: owner.lookup("service:site") as Site,
        signal,
      });
    },

    extract(
      cards: Map<number, TopicCardData>,
      descriptor: TopicCardDescriptor
    ) {
      // An unresolved topic renders empty rather than failing: the list drops
      // topics the viewer muted, and nothing in the response tells those apart
      // from ones that are gone. Only a failed request surfaces as an error.
      return (descriptor.topicId && cards.get(descriptor.topicId)) || null;
    },
  },
});

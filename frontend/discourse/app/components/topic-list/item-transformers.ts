import type Category from "discourse/models/category";
import type Topic from "discourse/models/topic";

/** Contract for the `topic-list-item-class` value transformer. */
export interface TopicListItemClassTransformer {
  value: string[];
  /** Index and list context depend on the renderer; category is absent outside a category filter. */
  context: {
    topic: Topic;
    index?: number;
    listContext?: string;
    category?: Category | null;
  };
  mutable: false;
}

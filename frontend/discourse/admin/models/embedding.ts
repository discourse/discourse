import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

/** An embeddable host; the store hydrates these from the embedding's `embeddable_host_ids`. */
export interface EmbeddableHost extends RestModel {
  id: number;
  host: string;
  allowed_paths: string | null;
  class_name: string | null;
  category_id: number;
  user: string | null;
  tags: { id: number; name: string; slug: string }[];
}

/** `/admin/customize/embedding` settings. */
export interface EmbeddingFields {
  id: string;
  fields: string[];
  base_url: string;
  embed_by_username: string;
  embed_post_limit: number;
  embed_title_scrubber: string;
  embed_truncate: boolean;
  embed_unlisted: boolean;
  allowed_embed_selectors: string;
  blocked_embed_selectors: string;
  allowed_embed_classnames: string;
  embeddable_host_ids?: number[];
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Embedding extends EmbeddingFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Embedding extends RestModel {
  @autoTrackedArray embeddable_hosts!: EmbeddableHost[];
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    embedding: Embedding;
  }
}

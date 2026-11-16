import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import RestModel, { type RestPayload } from "discourse/models/rest";

/** `/admin/permalinks` record; each target and its display fields are null unless it is the permalink's type. */
export interface PermalinkFields {
  id?: number;
  url: string;
  topic_id: number | null;
  topic_title: string | null;
  topic_url: string | null;
  post_id: number | null;
  post_url: string | null;
  post_number: number | null;
  post_topic_title: string | null;
  category_id: number | null;
  category_name: string | null;
  category_url: string | null;
  external_url: string | null;
  tag_id: number | null;
  tag_name: string | null;
  tag_url: string | null;
  user_id: number | null;
  user_url: string | null;
  username: string | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Permalink extends PermalinkFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Permalink extends RestModel {
  static async findAll(filter?: string | null): Promise<Permalink[]> {
    const data = await ajax<(PermalinkFields & RestPayload)[]>(
      "/admin/permalinks.json",
      {
        data: { filter },
      }
    );
    return data.map((p) => Permalink.create(p));
  }

  @computed("category_id")
  get category(): Category | undefined {
    return Category.findById(this.category_id);
  }

  @computed("external_url")
  get linkIsExternal(): boolean {
    return !DiscourseURL.isInternal(this.external_url);
  }

  @computed("url")
  get key(): string {
    return this.url.replace("/", "_");
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    permalink: Permalink;
  }
}

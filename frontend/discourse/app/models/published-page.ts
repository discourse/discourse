import { computed } from "@ember/object";
import { getAbsoluteURL } from "discourse/lib/get-url";
import RestModel from "discourse/models/rest";

/** Publication data; id identifies the topic rather than the publication row. */
export interface PublishedPageFields {
  id: number;
  slug: string;
  /** Local drafts copy a topic that may not have a public property. */
  public?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface PublishedPage extends PublishedPageFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class PublishedPage extends RestModel {
  @computed("slug")
  get url(): string {
    return getAbsoluteURL(`/pub/${this.slug}`);
  }
}

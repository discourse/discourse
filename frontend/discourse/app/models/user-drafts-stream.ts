import { computed } from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { cook, excerpt } from "discourse/lib/text";
import Category from "discourse/models/category";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import type User from "discourse/models/user";
import UserDraft, {
  type UserDraftData,
  type UserDraftFields,
} from "discourse/models/user-draft";

export default class UserDraftsStream extends RestModel {
  declare user?: User;

  limit = 30;
  loading = false;
  hasMore = false;

  content: UserDraft[] | null = null;

  override init(...args: Parameters<RestModel["init"]>) {
    super.init(...args);
    this.reset();
  }

  @computed("content.length", "loading")
  get noContent() {
    return this.content?.length === 0 && !this.loading;
  }

  reset() {
    this.setProperties({
      loading: false,
      hasMore: true,
      content: [],
    });
  }

  remove(draft: UserDraft) {
    this.set(
      "content",
      this.content!.filter((item) => item.draft_key !== draft.draft_key)
    );
  }

  findItems(site?: Site) {
    if (site) {
      this.set("site", site);
    }

    if (this.loading || !this.hasMore) {
      return Promise.resolve<void>();
    }

    this.set("loading", true);

    const url = `/drafts.json?offset=${this.content!.length}&limit=${this.limit}`;
    return ajax(url)
      .then(
        (
          result:
            | {
                drafts?: (Omit<UserDraftFields, "data" | "post_number"> & {
                  data: string;
                  post_number?: number | null;
                })[];
                categories?: Parameters<Site["updateCategory"]>[0][];
              }
            | null
            | undefined
        ) => {
          if (!result) {
            return;
          }

          if (!result.drafts) {
            return;
          }

          result.categories?.forEach((category) =>
            Site.current().updateCategory(category)
          );

          // The endpoint returns an array without size; preserve its undefined numeric comparison.
          this.set(
            "hasMore",
            (result.drafts as typeof result.drafts & { size?: number }).size! >=
              this.limit
          );

          // Each wire object is mutated in place: parse data first, then hydrate its derived fields.
          const promises = (result.drafts as unknown as UserDraftFields[]).map(
            (draft) => {
              draft.data = JSON.parse(
                draft.data as unknown as string
              ) as UserDraftData;
              // TODO(typescript-pending): cook's dynamic engine return is untyped; remove the annotation when cook publishes its HTML result.
              return cook(draft.data.reply).then((cooked: TrustedHTML) => {
                draft.excerpt = excerpt(cooked.toString(), 300);
                draft.post_number = draft.data.postId || null;
                if (
                  draft.draft_key.startsWith(NEW_PRIVATE_MESSAGE_KEY) ||
                  draft.draft_key.startsWith(NEW_TOPIC_KEY)
                ) {
                  draft.title = draft.data.title;
                }
                if (draft.data.categoryId) {
                  draft.category =
                    Category.findById(draft.data.categoryId) || null;
                }

                this.content!.push(
                  UserDraft.create(
                    draft as UserDraftFields & Record<string, unknown>
                  )
                );
              });
            }
          );

          return Promise.all(promises);
        }
      )
      .finally(() => {
        this.set("loading", false);
      });
  }
}

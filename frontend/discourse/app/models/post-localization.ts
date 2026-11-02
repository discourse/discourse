import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import type { TopicLocalizationData } from "discourse/models/topic-localization";

/** Plain localization responses; these helpers do not instantiate model records. */
export interface PostLocalizationData {
  id: number;
  post_id: number;
  post_version: number;
  locale: string;
  raw: string;
  /** Included only when a first post has a matching topic locale. */
  topic_localization?: TopicLocalizationData;
}

export default class PostLocalization extends RestModel {
  static find(
    postId: number
  ): Promise<{ post_localizations: PostLocalizationData[] }> {
    return ajax(`/post_localizations/${postId}`, {
      type: "GET",
      data: {
        post_id: postId,
      },
    });
  }

  static createOrUpdate(
    postId: number,
    locale: string,
    raw: string
  ): Promise<{ success: "OK" }> {
    return ajax("/post_localizations/create_or_update", {
      type: "POST",
      data: {
        post_id: postId,
        locale,
        raw,
      },
    });
  }

  static updateLocale(
    postId: number,
    locale: string | null | undefined
  ): Promise<{ locale: string | null }> {
    return ajax(`/post_localizations/${postId}/locale`, {
      type: "PUT",
      data: { locale: locale ?? "" },
    });
  }

  static destroy(postId: number, locale: string): Promise<void> {
    return ajax("/post_localizations/destroy", {
      type: "DELETE",
      data: {
        post_id: postId,
        locale,
      },
    });
  }
}

import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** Plain response shared by the topic endpoint and nested post localizations. */
export interface TopicLocalizationData {
  id: number;
  topic_id: number;
  locale: string;
  title: string;
  fancy_title: string;
}

export default class TopicLocalization extends RestModel {
  static fetch(
    topicId: number,
    locale: string
  ): Promise<TopicLocalizationData> {
    return ajax(`/topic_localizations/${topicId}/${locale}`);
  }

  static createOrUpdate(
    topicId: number,
    locale: string,
    title: string
  ): Promise<{ success: "OK" }> {
    return ajax("/topic_localizations/create_or_update", {
      type: "POST",
      data: {
        topic_id: topicId,
        locale,
        title,
      },
    });
  }

  static updateLocale(
    topicId: number,
    locale: string | null | undefined
  ): Promise<{ locale: string | null }> {
    return ajax(`/topic_localizations/${topicId}/locale`, {
      type: "PUT",
      data: { locale: locale ?? "" },
    });
  }

  static destroy(topicId: number, locale: string): Promise<void> {
    return ajax("/topic_localizations/destroy", {
      type: "DELETE",
      data: {
        topic_id: topicId,
        locale,
      },
    });
  }
}

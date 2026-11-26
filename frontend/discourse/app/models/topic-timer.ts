import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

/** The timer modal initially supplies only status_type. */
export interface TopicTimerFields {
  status_type: string;
  /** Whatever the time picker produced, before it is sent to the server. */
  updateTime?: unknown;
  id?: number;
  execute_at?: string | null;
  duration_minutes?: number | null;
  based_on_last_post?: boolean;
  category_id?: number | null;
}

/** The timer update endpoint returns a status hash, not a serialized timer. */
export interface TopicTimerUpdateResult {
  success: "OK";
  execute_at: string | null;
  duration_minutes: number | null;
  based_on_last_post: boolean | null;
  category_id: number | null;
  closed: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TopicTimer extends TopicTimerFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TopicTimer extends RestModel {
  /** Sends `time` as given; the time picker can produce more than formatted dates. */
  static update(
    topicId: number,
    time: unknown,
    basedOnLastPost: boolean | null | undefined,
    statusType: string,
    categoryId: number | null | undefined,
    durationMinutes: number | null | undefined
  ): Promise<TopicTimerUpdateResult> {
    // eslint-disable-next-line prefer-const -- Preserve the original Babel output.
    let data: {
      time: unknown;
      status_type: string;
      based_on_last_post?: boolean;
      category_id?: number;
      duration_minutes?: number;
    } = {
      time,
      status_type: statusType,
    };

    if (basedOnLastPost) {
      data.based_on_last_post = basedOnLastPost;
    }
    if (categoryId) {
      data.category_id = categoryId;
    }
    if (durationMinutes) {
      data.duration_minutes = durationMinutes;
    }

    return ajax({
      url: `/t/${topicId}/timer`,
      type: "POST",
      data,
    });
  }
}

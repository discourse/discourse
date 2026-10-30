import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

/** `tag` is listed only while tagging is enabled. */
export type WatchedWordAction =
  | "block"
  | "censor"
  | "require_approval"
  | "flag"
  | "link"
  | "replace"
  | "tag"
  | "silence";

/** Each entry maps one compiled pattern to its case sensitivity. */
export type WatchedWordRegularExpressions = Record<
  string,
  { case_sensitive: boolean }
>[];

/** `/admin/customize/watched_words` word; `replacement` and `html` are sent only when set. */
export interface WatchedWordPayload {
  id: number;
  word: string;
  regexp: string;
  replacement?: string | null;
  action: WatchedWordAction;
  case_sensitive: boolean;
  watched_word_group_id: number | null;
  html?: true;
}

/** The index and save responses. */
export interface WatchedWordListPayload {
  actions: WatchedWordAction[];
  words: WatchedWordPayload[];
  compiled_regular_expressions: Partial<
    Record<WatchedWordAction, WatchedWordRegularExpressions>
  >;
}

/** The add form builds unsaved records from camelCase form fields. */
export interface WatchedWordFields extends Omit<WatchedWordPayload, "id"> {
  id?: number;
  words?: string[];
  isCaseSensitive?: boolean;
  isHtml?: boolean;
  replacementTags?: { id?: number; name: string }[] | null;
}

/** One action's group, as `findAll` builds it. */
export interface WatchedWordGroup extends EmberObject {
  nameKey: WatchedWordAction;
  name: string;
  words: WatchedWord[];
  compiledRegularExpression: WatchedWordRegularExpressions;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface WatchedWord extends WatchedWordFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class WatchedWord extends EmberObject {
  static async findAll(): Promise<WatchedWordGroup[]> {
    // TODO(typescript-pending): ajax has no response generic; remove this assertion when it does.
    const list = (await ajax(
      "/admin/customize/watched_words.json"
    )) as WatchedWordListPayload;
    const actions = {} as Record<WatchedWordAction, WatchedWord[]>;

    list.actions.forEach((action) => {
      actions[action] = [];
    });

    list.words.forEach((watchedWord) => {
      actions[watchedWord.action].push(WatchedWord.create(watchedWord));
    });

    return (Object.keys(actions) as WatchedWordAction[]).map((nameKey) => {
      // EmberObject.create's inferred keys exclude these group properties.
      return EmberObject.create({
        nameKey,
        name: i18n("admin.watched_words.actions." + nameKey),
        words: trackedArray(actions[nameKey]),
        compiledRegularExpression: list.compiled_regular_expressions[nameKey],
      } as object) as WatchedWordGroup;
    });
  }

  save(): Promise<WatchedWordListPayload> {
    const data = {
      words: this.words,
      replacement: this.replacement,
      action_key: this.action,
      case_sensitive: this.isCaseSensitive,
      html: this.isHtml,
      replacement_tags: this.replacementTags,
    };

    return ajax(
      "/admin/customize/watched_words" +
        (this.id ? "/" + this.id : "") +
        ".json",
      {
        type: this.id ? "PUT" : "POST",
        data,
        dataType: "json",
      }
    );
  }

  /** Deletes the word on the server, unlike EmberObject's `destroy`. */
  destroy(this: never): never;
  destroy(): Promise<{ success: string }>;
  destroy(): Promise<{ success: string }> {
    return ajax("/admin/customize/watched_words/" + this.id + ".json", {
      type: "DELETE",
    });
  }
}

import { tracked } from "@glimmer/tracking";
import singleton from "discourse/lib/singleton";
import type Bookmark from "discourse/models/bookmark";
import type CategoryList from "discourse/models/category-list";
import RestModel from "discourse/models/rest";
import type TopicList from "discourse/models/topic-list";

/** Transient state assigned by boot and client consumers; never a server payload. */
export interface SessionFields {
  assetVersion?: string;
  bookmarksModel?: {
    bookmarks: Bookmark[];
    loadMoreUrl?: string | null;
    searchTerm?: string | null;
  } | null;
  csrfToken?: string | null;
  darkModeAvailable?: boolean;
  defaultColorSchemeIsDark?: boolean;
  disableCustomCSS?: boolean;
  /** Read during signup; no production writer is currently known. */
  email?: string | null;
  hideSignupCta?: boolean;
  highestSeenByTopic: Record<number, number | null | undefined>;
  highlightJsPath?: string;
  mbLastFileChangeId?: number;
  safe_mode?: string;
  serviceWorkerURL?: string;
  showSignupCta?: boolean;
  svgSpritePath?: string;
  topicList?: TopicList | CategoryList | null;
  userColorSchemeId?: number;
  userDarkSchemeId?: number;
  [key: `user-menu-items:${string}`]: unknown[] | undefined;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Session extends SessionFields {}

/**
 * A data model representing current session data. You can put transient
 * data here you might want later. It is not stored or serialized anywhere.
 */
@singleton
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Session extends RestModel {
  /** Creates the default instance. Added by `@singleton`. */
  declare static createCurrent: () => Session;

  /** The session, created on first use. Added by `@singleton`. */
  declare static current: () => Session;

  /** Reads or sets a property; dynamic keys and property paths remain untyped. */
  declare static currentProp: {
    <K extends keyof Session>(property: K): Session[K];
    <K extends keyof Session>(property: K, value: Session[K]): Session[K];
    <P extends string>(
      property: P extends keyof Session ? never : P,
      value?: unknown
    ): unknown;
  };

  /** Replaces the cached instance. Added by `@singleton`. */
  declare static resetCurrent: <
    T extends Session | null | undefined = undefined,
  >(
    value?: T
  ) => T;

  @tracked requiresRefresh = false;

  hasFocus: boolean | null = null;

  /** Cached instance managed by `@singleton`. */
  declare static _current: Session | null | undefined;

  init() {
    this.set("highestSeenByTopic", {});
  }
}

/**
 * Base properties shared across all autocomplete result types
 */
interface BaseAutocompleteResult {
  /** Optional index for tracking */
  index?: number;
}

/**
 * User autocomplete result type
 */
export interface UserAutocompleteResult extends BaseAutocompleteResult {
  isUser: true;
  isEmail?: never;
  isGroup?: never;
  username: string;
  name?: string;
  status?: unknown;
  cssClasses?: string;
}

/**
 * Email autocomplete result type
 */
export interface EmailAutocompleteResult extends BaseAutocompleteResult {
  isUser?: never;
  isEmail: true;
  isGroup?: never;
  username: string;
}

/**
 * Group autocomplete result type
 */
export interface GroupAutocompleteResult extends BaseAutocompleteResult {
  isUser?: never;
  isEmail?: never;
  isGroup: true;
  name: string;
  full_name?: string;
}

/**
 * Union type for all user/email/group autocomplete results
 */
export type UserEmailGroupResult =
  | UserAutocompleteResult
  | EmailAutocompleteResult
  | GroupAutocompleteResult;

/**
 * Hashtag autocomplete result type (for simple hashtag autocomplete)
 * Represents both categories and tags in their basic form
 */
export interface HashtagAutocompleteResult extends BaseAutocompleteResult {
  /** Category model object (if it's a category) */
  model?: unknown;
  /** Tag name (if it's a tag) */
  name?: string;
  /** Tag count (if it's a tag) */
  count?: number;
}

/**
 * Rich hashtag autocomplete result type (for rich hashtag autocomplete)
 * Represents both categories and tags with rich metadata (icons, colors, descriptions)
 */
export interface RichHashtagAutocompleteResult extends BaseAutocompleteResult {
  /** Display text for the hashtag */
  text: string;
  /** Optional secondary text */
  secondary_text?: string;
  /** Description shown in title attribute */
  description?: string;
  /** HTML string for the icon */
  iconHtml: string;
}

/**
 * Generic type signature for autocomplete results component
 * @template T - The type of result items in the autocomplete
 */
export interface AutocompleteResultsSignature<T> {
  Args: {
    /** Array of autocomplete results */
    results: Array<T>;
    /** Currently selected index in the results list */
    selectedIndex: number;
    /** Callback function triggered when a result is selected */
    onSelect: (result: T, index: number, event: Event) => void;
    /** Optional callback function triggered after component renders */
    onRender?: (results: Array<T>) => void;
  };
}

import type { HomeLogoMinimizedTransformer } from "discourse/components/header/contents-transformers";
import type { SearchMenuSearchShortcutsEnabledTransformer } from "discourse/components/search-menu/results/initial-options-transformers";
import type { DraftIconTransformer } from "discourse/components/topic-drafts-dropdown-transformers";
import type { TopicListItemClassTransformer } from "discourse/components/topic-list/item-transformers";
import type { PreferencesSaveAttributesTransformer } from "discourse/controllers/preferences/transformers";

/** Opaque marker for a known hook that retains generic value and context inference. */
declare const untypedBrand: unique symbol;

/** Marks a known hook whose value, context, and mutability are not yet specified. */
export type Untyped = { readonly [untypedBrand]: true };

declare const contractBrand: unique symbol;

/** Runtime placeholder whose type parameter carries a hook's contract. */
interface Typed<Entry> {
  readonly [contractBrand]: Entry;
}

const untyped = Object.freeze({}) as Untyped;

function typed<Entry>(): Typed<Entry> {
  return untyped as unknown as Typed<Entry>;
}

/* eslint sort-keys: ["error", "asc", { "natural": true }] */

type EntriesOf<Hooks> = {
  [Name in keyof Hooks]: Hooks[Name] extends Typed<infer Entry>
    ? Entry
    : Untyped;
};

/**
 * Behavior transformers allow plugins and themes to modify or enhance specific behaviors and interactions.
 * They are invoked at key points to allow customization of the application behavior.
 *
 * Each key is a hook name (USE ONLY lowercase names). The value is `untyped`, or `typed<Contract>()` where
 * `Contract` is `{ result: R; context: C | undefined }`. Declare a contract in a types-only `.ts` file next to the
 * code that applies the hook: `<owner>-transformers.ts` beside a single owner, or `transformers.ts` in a directory
 * whose files share the hook.
 */
const BEHAVIOR_HOOKS = {
  "admin-user-unsilence": untyped,
  "admin-user-unsuspend": untyped,
  "apply-local-dates": untyped,
  "category-visibility-change": untyped,
  "composer-actions-on-select": untyped,
  "composer-apply-topic-template": untyped,
  "composer-open": untyped,
  "composer-position:correct-scroll-position": untyped,
  "composer-position:editor-touch-move": untyped,
  "create-account": untyped,
  "create-topic-button-click": untyped,
  "custom-homepage-model": untyped,
  "discovery-topic-list-load-more": untyped,
  "full-page-search-load-more": untyped,
  "post-menu-toggle-like-action": untyped,
  "post-stream-error-loading": untyped,
  "post-stream-suggested-topics": untyped,
  "post-stream-update-from-json": untyped,
  "search-menu-clear-recent-searches": untyped,
  "search-menu-clear-search": untyped,
  "topic-controller:finished-editing": untyped,
  "topic-list-item-click": untyped,
  "topic-update-from-json": untyped,
};

/**
 * Value transformers allow plugins and themes to modify or replace specific values before they are used by the
 * application. Each transformer represents a specific value or computation that can be customized.
 *
 * Each key is a hook name (USE ONLY lowercase names). The value is `untyped`, or `typed<Contract>()` where
 * `Contract` is `{ value: V; context: C | undefined; mutable: true | false }`, declared like behavior contracts.
 */
const VALUE_HOOKS = {
  "admin-dashboard-report-renderer": untyped,
  "admin-onboarding-start-posting-options": untyped,
  "admin-plugin-icon": untyped,
  "admin-reports-show-query-params": untyped,
  "admin-theme-card-show-full-controls": untyped,
  "bulk-select-in-nav-controls": untyped,
  "can-create-topic-button": untyped,
  "category-available-views": untyped,
  "category-default-colors": untyped,
  "category-description-text": untyped,
  "category-display-name": untyped,
  "category-list-attributes": untyped,
  "category-list-request": untyped,
  "category-list-subcategories": untyped,
  "category-sort-orders": untyped,
  "category-subcategories": untyped,
  "category-text-color": untyped,
  "category-visibility-private-locked": untyped,
  "code-login-auto-create-account": untyped,
  "code-login-user-field-values": untyped,
  "composer-actions-content": untyped,
  "composer-editing-post": untyped,
  "composer-editor-quoted-post-avatar-template": untyped,
  "composer-editor-reply-placeholder": untyped,
  "composer-force-editor-mode": untyped,
  "composer-message-components": untyped,
  "composer-minimum-post-length": untyped,
  "composer-reply-options-user-avatar-template": untyped,
  "composer-reply-options-user-link-name": untyped,
  "composer-save-button-label": untyped,
  "composer-service-cannot-submit-post": untyped,
  "composer-toggles-class": untyped,
  "composer-user": untyped,
  "create-topic-button-class": untyped,
  "create-topic-button-draft-menu-class": untyped,
  "create-topic-icon": untyped,
  "create-topic-label": untyped,
  "draft-icon": typed<DraftIconTransformer>(),
  "flag-button-disabled-state": untyped,
  "flag-button-dynamic-class": untyped,
  "flag-button-render-decision": untyped,
  "flag-custom-placeholder": untyped,
  "flag-description": untyped,
  "flag-formatted-name": untyped,
  "full-page-refresh-on-navigation": untyped,
  "full-page-search-button-icon": untyped,
  "full-page-search-button-label": untyped,
  "full-page-search-no-results-enabled": untyped,
  "full-page-search-types": untyped,
  "group-members-request": untyped,
  "hamburger-dropdown-click-outside-exceptions": untyped,
  "header-notifications-avatar-size": untyped,
  "home-logo-href": untyped,
  "home-logo-image-url": untyped,
  "home-logo-minimized": typed<HomeLogoMinimizedTransformer>(),
  "invite-simple-mode-topic": untyped,
  "latest-topic-list-item-class": untyped,
  "like-button-render-decision": untyped,
  "mentions-class": untyped,
  "more-topics-tabs": untyped,
  "move-to-topic-merge-options": untyped,
  "move-to-topic-move-options": untyped,
  "navigation-bar-dropdown-icon": untyped,
  "navigation-bar-dropdown-mode": untyped,
  "navigation-items": untyped,
  "notifications-tracking-description": untyped,
  "parent-category-row-class": untyped,
  "parent-category-row-class-mobile": untyped,
  "post-article-class": untyped,
  "post-avatar-class": untyped,
  "post-avatar-size": untyped,
  "post-avatar-template": untyped,
  "post-can-edit": untyped,
  "post-class": untyped,
  "post-event-listener": untyped,
  "post-flag-available-flags": untyped,
  "post-flag-title": untyped,
  "post-is-small-action": untyped,
  "post-language-selector-priority": untyped,
  "post-menu-buttons": untyped,
  "post-menu-collapsed": untyped,
  "post-menu-like-button-icon": untyped,
  "post-meta-data-edits-indicator-label": untyped,
  "post-meta-data-infos": untyped,
  "post-meta-data-poster-name-suppress-similar-name": untyped,
  "post-notice-component": untyped,
  "post-show-topic-map": untyped,
  "post-small-action-class": untyped,
  "post-small-action-custom-component": untyped,
  "post-small-action-icon": untyped,
  "poster-name-class": untyped,
  "poster-name-icons": untyped,
  "poster-name-user-title": untyped,
  "preferences-save-attributes": typed<PreferencesSaveAttributesTransformer>(),
  "quote-params": untyped,
  "reviewable-component": untyped,
  "route-to-url": untyped,
  "search-advanced-icon-enabled": untyped,
  "search-menu-advanced-button-enabled": untyped,
  "search-menu-full-search-params": untyped,
  "search-menu-indexed-results-enabled": untyped,
  "search-menu-input-placeholder": untyped,
  "search-menu-input-wrapper-classes": untyped,
  "search-menu-recent-searches": untyped,
  "search-menu-search-context-enabled": untyped,
  "search-menu-search-shortcuts-enabled":
    typed<SearchMenuSearchShortcutsEnabledTransformer>(),
  "search-result-entry-class": untyped,
  "sidebar-anonymous-default-categories": untyped,
  "sidebar-panel": untyped,
  "site-setting-allows-none": untyped,
  "small-user-attrs": untyped,
  "tag-separator": untyped,
  "topic-escaped-excerpt": untyped,
  "topic-list-class": untyped,
  "topic-list-columns": untyped,
  "topic-list-header-sortable-column": untyped,
  "topic-list-item-class": typed<TopicListItemClassTransformer>(),
  "topic-list-item-expand-pinned": untyped,
  "topic-list-item-mobile-layout": untyped,
  "topic-list-item-style": untyped,
  "topic-list-topics-from": untyped,
  "topic-navigation-render-timeline": untyped,
  "topic-reply-count": untyped,
  "topic-show-footer-buttons": untyped,
  "user-field-components": untyped,
  "user-list-display-name": untyped,
  "user-list-display-username": untyped,
  "user-location": untyped,
  "user-menu-notification-item-acting-user-avatar": untyped,
  "user-notes-modal-subtitle": untyped,
  "user-path": untyped,
  "welcome-banner-display-for-route": untyped,
  "welcome-banner-location": untyped,
};

/**
 * Behavior hook contracts, augmented through `discourse/lib/transformer`.
 * Entries require `result` and `context` (use `undefined` when absent).
 * A `void` result intentionally ignores middleware return values.
 */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface BehaviorTransformerRegistry extends EntriesOf<
  typeof BEHAVIOR_HOOKS
> {}

/**
 * Value hook contracts, augmented through `discourse/lib/transformer`.
 * Entries require `value`, `context` (use `undefined` when absent), and literal `mutable: true` or `false`.
 * Immutable values cannot be `void`; callbacks must return the transformed value.
 */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type
export interface ValueTransformerRegistry extends EntriesOf<
  typeof VALUE_HOOKS
> {}

/** Names of the core behavior transformers. */
export const BEHAVIOR_TRANSFORMERS = Object.freeze(
  Object.keys(BEHAVIOR_HOOKS)
) as readonly (keyof typeof BEHAVIOR_HOOKS)[];

/** Names of the core value transformers. */
export const VALUE_TRANSFORMERS = Object.freeze(
  Object.keys(VALUE_HOOKS)
) as readonly (keyof typeof VALUE_HOOKS)[];

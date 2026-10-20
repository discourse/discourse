import type Category from "discourse/models/category";
import type Topic from "discourse/models/topic";
import type UserDraft from "discourse/models/user-draft";

/** Opaque marker for a known hook that retains generic value and context inference. */
declare const untyped: unique symbol;

/** Marks a known hook whose value, context, and mutability are not yet specified. */
export type Untyped = { readonly [untyped]: true };

export type PreferencesPage =
  | "account"
  | "emails"
  | "interface"
  | "navigation-menu"
  | "notifications"
  | "profile"
  | "tags"
  | "tracking"
  | "users";

/**
 * Value hook contracts, augmented through `discourse/lib/transformer`.
 * Entries require `value`, `context` (use `undefined` when absent), and literal `mutable: true` or `false`.
 * Immutable values cannot be `void`; callbacks must return the transformed value.
 */
export interface ValueTransformerRegistry {
  "admin-dashboard-report-renderer": Untyped;
  "admin-onboarding-start-posting-options": Untyped;
  "admin-plugin-icon": Untyped;
  "admin-reports-show-query-params": Untyped;
  "admin-theme-card-show-full-controls": Untyped;
  "bulk-select-in-nav-controls": Untyped;
  "can-create-topic-button": Untyped;
  "category-available-views": Untyped;
  "category-default-colors": Untyped;
  "category-description-text": Untyped;
  "category-display-name": Untyped;
  "category-list-attributes": Untyped;
  "category-list-request": Untyped;
  "category-list-subcategories": Untyped;
  "category-sort-orders": Untyped;
  "category-subcategories": Untyped;
  "category-text-color": Untyped;
  "category-visibility-private-locked": Untyped;
  "code-login-auto-create-account": Untyped;
  "code-login-user-field-values": Untyped;
  "composer-actions-content": Untyped;
  "composer-editing-post": Untyped;
  "composer-editor-quoted-post-avatar-template": Untyped;
  "composer-editor-reply-placeholder": Untyped;
  "composer-force-editor-mode": Untyped;
  "composer-message-components": Untyped;
  "composer-minimum-post-length": Untyped;
  "composer-reply-options-user-avatar-template": Untyped;
  "composer-reply-options-user-link-name": Untyped;
  "composer-save-button-label": Untyped;
  "composer-service-cannot-submit-post": Untyped;
  "composer-toggles-class": Untyped;
  "composer-user": Untyped;
  "create-topic-button-class": Untyped;
  "create-topic-button-draft-menu-class": Untyped;
  "create-topic-icon": Untyped;
  "create-topic-label": Untyped;
  "draft-icon": {
    value: string;
    context: { draft: UserDraft };
    mutable: false;
  };
  "flag-button-disabled-state": Untyped;
  "flag-button-dynamic-class": Untyped;
  "flag-button-render-decision": Untyped;
  "flag-custom-placeholder": Untyped;
  "flag-description": Untyped;
  "flag-formatted-name": Untyped;
  "full-page-refresh-on-navigation": Untyped;
  "full-page-search-button-icon": Untyped;
  "full-page-search-button-label": Untyped;
  "full-page-search-no-results-enabled": Untyped;
  "full-page-search-types": Untyped;
  "group-members-request": Untyped;
  "hamburger-dropdown-click-outside-exceptions": Untyped;
  "header-notifications-avatar-size": Untyped;
  "home-logo-href": Untyped;
  "home-logo-image-url": Untyped;
  "home-logo-minimized": {
    value: boolean;
    context: {
      /** Null when no topic page is open. */
      topicInfo: Topic | null;
      sidebarEnabled: boolean;
      showSidebar: boolean;
    };
    mutable: false;
  };
  "invite-simple-mode-topic": Untyped;
  "latest-topic-list-item-class": Untyped;
  "like-button-render-decision": Untyped;
  "mentions-class": Untyped;
  "more-topics-tabs": Untyped;
  "move-to-topic-merge-options": Untyped;
  "move-to-topic-move-options": Untyped;
  "navigation-bar-dropdown-icon": Untyped;
  "navigation-bar-dropdown-mode": Untyped;
  "navigation-items": Untyped;
  "notifications-tracking-description": Untyped;
  "parent-category-row-class": Untyped;
  "parent-category-row-class-mobile": Untyped;
  "post-article-class": Untyped;
  "post-avatar-class": Untyped;
  "post-avatar-size": Untyped;
  "post-avatar-template": Untyped;
  "post-can-edit": Untyped;
  "post-class": Untyped;
  "post-event-listener": Untyped;
  "post-flag-available-flags": Untyped;
  "post-flag-title": Untyped;
  "post-is-small-action": Untyped;
  "post-language-selector-priority": Untyped;
  "post-menu-buttons": Untyped;
  "post-menu-collapsed": Untyped;
  "post-menu-like-button-icon": Untyped;
  "post-meta-data-edits-indicator-label": Untyped;
  "post-meta-data-infos": Untyped;
  "post-meta-data-poster-name-suppress-similar-name": Untyped;
  "post-notice-component": Untyped;
  "post-show-topic-map": Untyped;
  "post-small-action-class": Untyped;
  "post-small-action-custom-component": Untyped;
  "post-small-action-icon": Untyped;
  "poster-name-class": Untyped;
  "poster-name-icons": Untyped;
  "poster-name-user-title": Untyped;
  "preferences-save-attributes": {
    value: string[];
    context: { page: PreferencesPage };
    mutable: false;
  };
  "quote-params": Untyped;
  "reviewable-component": Untyped;
  "route-to-url": Untyped;
  "search-advanced-icon-enabled": Untyped;
  "search-menu-advanced-button-enabled": Untyped;
  "search-menu-full-search-params": Untyped;
  "search-menu-indexed-results-enabled": Untyped;
  "search-menu-input-placeholder": Untyped;
  "search-menu-input-wrapper-classes": Untyped;
  "search-menu-recent-searches": Untyped;
  "search-menu-search-context-enabled": Untyped;
  "search-menu-search-shortcuts-enabled": {
    value: boolean;
    context: { location?: string };
    mutable: false;
  };
  "search-result-entry-class": Untyped;
  "sidebar-anonymous-default-categories": Untyped;
  "sidebar-panel": Untyped;
  "site-setting-allows-none": Untyped;
  "small-user-attrs": Untyped;
  "tag-separator": Untyped;
  "topic-escaped-excerpt": Untyped;
  "topic-list-class": Untyped;
  "topic-list-columns": Untyped;
  "topic-list-header-sortable-column": Untyped;
  /** Index and list context depend on the renderer; category is absent outside a category filter. */
  "topic-list-item-class": {
    value: string[];
    context: {
      topic: Topic;
      index?: number;
      listContext?: string;
      category?: Category | null;
    };
    mutable: false;
  };
  "topic-list-item-expand-pinned": Untyped;
  "topic-list-item-mobile-layout": Untyped;
  "topic-list-item-style": Untyped;
  "topic-list-topics-from": Untyped;
  "topic-navigation-render-timeline": Untyped;
  "topic-reply-count": Untyped;
  "topic-show-footer-buttons": Untyped;
  "user-field-components": Untyped;
  "user-list-display-name": Untyped;
  "user-list-display-username": Untyped;
  "user-location": Untyped;
  "user-menu-notification-item-acting-user-avatar": Untyped;
  "user-notes-modal-subtitle": Untyped;
  "user-path": Untyped;
  "welcome-banner-display-for-route": Untyped;
  "welcome-banner-location": Untyped;
}

/**
 * Behavior hook contracts, augmented through `discourse/lib/transformer`.
 * Entries require `result` and `context` (use `undefined` when absent).
 * A `void` result intentionally ignores middleware return values.
 */
export interface BehaviorTransformerRegistry {
  "admin-user-unsilence": Untyped;
  "admin-user-unsuspend": Untyped;
  "apply-local-dates": Untyped;
  "category-visibility-change": Untyped;
  "composer-actions-on-select": Untyped;
  "composer-apply-topic-template": Untyped;
  "composer-open": Untyped;
  "composer-position:correct-scroll-position": Untyped;
  "composer-position:editor-touch-move": Untyped;
  "create-account": Untyped;
  "create-topic-button-click": Untyped;
  "custom-homepage-model": Untyped;
  "discovery-topic-list-load-more": Untyped;
  "full-page-search-load-more": Untyped;
  "post-menu-toggle-like-action": Untyped;
  "post-stream-error-loading": Untyped;
  "post-stream-suggested-topics": Untyped;
  "post-stream-update-from-json": Untyped;
  "search-menu-clear-recent-searches": Untyped;
  "topic-controller:finished-editing": Untyped;
  "topic-list-item-click": Untyped;
  "topic-update-from-json": Untyped;
}

/**
 * Registry of available behavior transformers in the application.
 * Behavior transformers allow plugins and themes to modify or enhance the specific behaviors and interactions.
 * These transformers are invoked at key points to allow customization of the application behavior.
 *
 * USE ONLY lowercase names
 */
// eslint-discourse keep-array-sorted
export const BEHAVIOR_TRANSFORMERS = Object.freeze([
  "admin-user-unsilence",
  "admin-user-unsuspend",
  "apply-local-dates",
  "category-visibility-change",
  "composer-actions-on-select",
  "composer-apply-topic-template",
  "composer-open",
  "composer-position:correct-scroll-position",
  "composer-position:editor-touch-move",
  "create-account",
  "create-topic-button-click",
  "custom-homepage-model",
  "discovery-topic-list-load-more",
  "full-page-search-load-more",
  "post-menu-toggle-like-action",
  "post-stream-error-loading",
  "post-stream-suggested-topics",
  "post-stream-update-from-json",
  "search-menu-clear-recent-searches",
  "search-menu-clear-search",
  "topic-controller:finished-editing",
  "topic-list-item-click",
  "topic-update-from-json",
] as const satisfies readonly (keyof BehaviorTransformerRegistry)[]);

/**
 * Registry of available value transformers in the application.
 * Value transformers allow plugins and themes to modify or replace specific values before they are used by the application.
 * Each transformer represents a specific value or computation that can be customized.
 *
 * USE ONLY lowercase names
 */
// eslint-discourse keep-array-sorted
export const VALUE_TRANSFORMERS = Object.freeze([
  "admin-dashboard-report-renderer",
  "admin-onboarding-start-posting-options",
  "admin-plugin-icon",
  "admin-reports-show-query-params",
  "admin-theme-card-show-full-controls",
  "bulk-select-in-nav-controls",
  "can-create-topic-button",
  "category-available-views",
  "category-default-colors",
  "category-description-text",
  "category-display-name",
  "category-list-attributes",
  "category-list-request",
  "category-list-subcategories",
  "category-sort-orders",
  "category-subcategories",
  "category-text-color",
  "category-visibility-private-locked",
  "code-login-auto-create-account",
  "code-login-user-field-values",
  "composer-actions-content",
  "composer-editing-post",
  "composer-editor-quoted-post-avatar-template",
  "composer-editor-reply-placeholder",
  "composer-force-editor-mode",
  "composer-message-components",
  "composer-minimum-post-length",
  "composer-reply-options-user-avatar-template",
  "composer-reply-options-user-link-name",
  "composer-save-button-label",
  "composer-service-cannot-submit-post",
  "composer-toggles-class",
  "composer-user",
  "create-topic-button-class",
  "create-topic-button-draft-menu-class",
  "create-topic-icon",
  "create-topic-label",
  "draft-icon",
  "flag-button-disabled-state",
  "flag-button-dynamic-class",
  "flag-button-render-decision",
  "flag-custom-placeholder",
  "flag-description",
  "flag-formatted-name",
  "full-page-refresh-on-navigation",
  "full-page-search-button-icon",
  "full-page-search-button-label",
  "full-page-search-no-results-enabled",
  "full-page-search-types",
  "group-members-request",
  "hamburger-dropdown-click-outside-exceptions",
  "header-notifications-avatar-size",
  "home-logo-href",
  "home-logo-image-url",
  "home-logo-minimized",
  "invite-simple-mode-topic",
  "latest-topic-list-item-class",
  "like-button-render-decision",
  "mentions-class",
  "more-topics-tabs",
  "move-to-topic-merge-options",
  "move-to-topic-move-options",
  "navigation-bar-dropdown-icon",
  "navigation-bar-dropdown-mode",
  "navigation-items",
  "notifications-tracking-description",
  "parent-category-row-class",
  "parent-category-row-class-mobile",
  "post-article-class",
  "post-avatar-class",
  "post-avatar-size",
  "post-avatar-template",
  "post-can-edit",
  "post-class",
  "post-event-listener",
  "post-flag-available-flags",
  "post-flag-title",
  "post-is-small-action",
  "post-language-selector-priority",
  "post-menu-buttons",
  "post-menu-collapsed",
  "post-menu-like-button-icon",
  "post-meta-data-edits-indicator-label",
  "post-meta-data-infos",
  "post-meta-data-poster-name-suppress-similar-name",
  "post-notice-component",
  "post-show-topic-map",
  "post-small-action-class",
  "post-small-action-custom-component",
  "post-small-action-icon",
  "poster-name-class",
  "poster-name-icons",
  "poster-name-user-title",
  "preferences-save-attributes",
  "quote-params",
  "reviewable-component",
  "route-to-url",
  "search-advanced-icon-enabled",
  "search-menu-advanced-button-enabled",
  "search-menu-full-search-params",
  "search-menu-indexed-results-enabled",
  "search-menu-input-placeholder",
  "search-menu-input-wrapper-classes",
  "search-menu-recent-searches",
  "search-menu-search-context-enabled",
  "search-menu-search-shortcuts-enabled",
  "search-result-entry-class",
  "sidebar-anonymous-default-categories",
  "sidebar-panel",
  "site-setting-allows-none",
  "small-user-attrs",
  "tag-separator",
  "topic-escaped-excerpt",
  "topic-list-class",
  "topic-list-columns",
  "topic-list-header-sortable-column",
  "topic-list-item-class",
  "topic-list-item-expand-pinned",
  "topic-list-item-mobile-layout",
  "topic-list-item-style",
  "topic-list-topics-from",
  "topic-navigation-render-timeline",
  "topic-reply-count",
  "topic-show-footer-buttons",
  "user-field-components",
  "user-list-display-name",
  "user-list-display-username",
  "user-location",
  "user-menu-notification-item-acting-user-avatar",
  "user-notes-modal-subtitle",
  "user-path",
  "welcome-banner-display-for-route",
  "welcome-banner-location",
] as const satisfies readonly (keyof ValueTransformerRegistry)[]);

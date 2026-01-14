/**
 * Registry of available behavior transformers in the application.
 * Behavior transformers allow plugins and themes to modify or enhance the specific behaviors and interactions.
 * These transformers are invoked at key points to allow customization of the application behavior.
 *
 * USE ONLY lowercase names
 *
 * @constant {ReadonlyArray<string>} BEHAVIOR_TRANSFORMERS - An immutable array of behavior transformer identifiers
 */
// eslint-discourse keep-array-sorted
export const BEHAVIOR_TRANSFORMERS = Object.freeze([
  "composer-position:correct-scroll-position",
  "composer-position:editor-touch-move",
  "discovery-topic-list-load-more",
  "full-page-search-load-more",
  "post-menu-toggle-like-action",
  "post-stream-error-loading",
  "topic-list-item-click",
]);

/**
 * Registry of available value transformers in the application.
 * Value transformers allow plugins and themes to modify or replace specific values before they are used by the application.
 * Each transformer represents a specific value or computation that can be customized.
 *
 * USE ONLY lowercase names
 *
 * @constant {ReadonlyArray<string>} VALUE_TRANSFORMERS - An immutable array of value transformer identifiers
 */
// eslint-discourse keep-array-sorted
export const VALUE_TRANSFORMERS = Object.freeze([
  "admin-plugin-icon",
  "admin-reports-show-query-params",
  "bulk-select-in-nav-controls",
  "category-available-views",
  "category-default-colors",
  "category-description-text",
  "category-display-name",
  "category-sort-orders",
  "category-text-color",
  "composer-editor-quoted-post-avatar-template",
  "composer-editor-reply-placeholder",
  "composer-force-editor-mode",
  "composer-message-components",
  "composer-reply-options-user-avatar-template",
  "composer-reply-options-user-link-name",
  "composer-save-button-label",
  "composer-service-cannot-submit-post",
  "composer-toggles-class",
  "create-topic-label",
  "create-topic-button-class",
  "flag-button-disabled-state",
  "flag-button-dynamic-class",
  "flag-button-render-decision",
  "flag-custom-placeholder",
  "flag-description",
  "flag-formatted-name",
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
  "parent-category-row-class",
  "parent-category-row-class-mobile",
  "post-article-class",
  "post-avatar-class",
  "post-avatar-size",
  "post-avatar-template",
  "post-class",
  "post-event-listener",
  "post-flag-available-flags",
  "post-flag-title",
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
  "small-user-attrs",
  "tag-separator",
  "topic-list-class",
  "topic-list-columns",
  "topic-list-header-sortable-column",
  "topic-list-item-class",
  "topic-list-item-expand-pinned",
  "topic-list-item-mobile-layout",
  "topic-list-item-style",
  "user-field-components",
  "user-menu-notification-item-acting-user-avatar",
  "user-notes-modal-subtitle",
]);

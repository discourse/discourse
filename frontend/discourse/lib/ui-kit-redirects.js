"use strict";

// Maps old module paths (as rewritten by Embroider) to new ui-kit paths.
// Used by NormalModuleReplacementPlugin in ember-cli-build.js to redirect
// at webpack build time. loaderShim in ui-kit-shims.js handles runtime AMD.

module.exports = {
  // Components - already d-prefixed (moved without rename)
  "discourse/components/d-autocomplete-results":
    "discourse/ui-kit/d-autocomplete-results",
  "discourse/components/d-breadcrumbs-container":
    "discourse/ui-kit/d-breadcrumbs-container",
  "discourse/components/d-breadcrumbs-item":
    "discourse/ui-kit/d-breadcrumbs-item",
  "discourse/components/d-button": "discourse/ui-kit/d-button",
  "discourse/components/d-combo-button": "discourse/ui-kit/d-combo-button",
  "discourse/components/d-editor": "discourse/ui-kit/d-editor",
  "discourse/components/d-modal": "discourse/ui-kit/d-modal",
  "discourse/components/d-modal-cancel": "discourse/ui-kit/d-modal-cancel",
  "discourse/components/d-multi-select": "discourse/ui-kit/d-multi-select",
  "discourse/components/d-navigation-item":
    "discourse/ui-kit/d-navigation-item",
  "discourse/components/d-otp": "discourse/ui-kit/d-otp",
  "discourse/components/d-otp/index": "discourse/ui-kit/d-otp/index",
  "discourse/components/d-otp/slot": "discourse/ui-kit/d-otp/slot",
  "discourse/components/d-page-action-button":
    "discourse/ui-kit/d-page-action-button",
  "discourse/components/d-page-header": "discourse/ui-kit/d-page-header",
  "discourse/components/d-page-subheader": "discourse/ui-kit/d-page-subheader",
  "discourse/components/d-select": "discourse/ui-kit/d-select",
  "discourse/components/d-stat-tiles": "discourse/ui-kit/d-stat-tiles",
  "discourse/components/d-textarea": "discourse/ui-kit/d-textarea",
  "discourse/components/d-toggle-switch": "discourse/ui-kit/d-toggle-switch",

  // Components - renamed (old unprefixed -> new d-prefixed)
  "discourse/components/async-content": "discourse/ui-kit/d-async-content",
  "discourse/components/avatar-flair": "discourse/ui-kit/d-avatar-flair",
  "discourse/components/badge-button": "discourse/ui-kit/d-badge-button",
  "discourse/components/badge-card": "discourse/ui-kit/d-badge-card",
  "discourse/components/calendar-date-time-input":
    "discourse/ui-kit/d-calendar-date-time-input",
  "discourse/components/cdn-img": "discourse/ui-kit/d-cdn-img",
  "discourse/components/char-counter": "discourse/ui-kit/d-char-counter",
  "discourse/components/color-picker": "discourse/ui-kit/d-color-picker",
  "discourse/components/color-picker-choice":
    "discourse/ui-kit/d-color-picker-choice",
  "discourse/components/conditional-in-element":
    "discourse/ui-kit/d-conditional-in-element",
  "discourse/components/conditional-loading-section":
    "discourse/ui-kit/d-conditional-loading-section",
  "discourse/components/conditional-loading-spinner":
    "discourse/ui-kit/d-conditional-loading-spinner",
  "discourse/components/cook-text": "discourse/ui-kit/d-cook-text",
  "discourse/components/copy-button": "discourse/ui-kit/d-copy-button",
  "discourse/components/count-i18n": "discourse/ui-kit/d-count-i18n",
  "discourse/components/custom-html": "discourse/ui-kit/d-custom-html",
  "discourse/components/date-input": "discourse/ui-kit/d-date-input",
  "discourse/components/date-picker": "discourse/ui-kit/d-date-picker",
  "discourse/components/date-time-input": "discourse/ui-kit/d-date-time-input",
  "discourse/components/date-time-input-range":
    "discourse/ui-kit/d-date-time-input-range",
  "discourse/components/decorated-html": "discourse/ui-kit/d-decorated-html",
  "discourse/components/dropdown-menu": "discourse/ui-kit/d-dropdown-menu",
  "discourse/components/empty-state": "discourse/ui-kit/d-empty-state",
  "discourse/components/expanding-text-area":
    "discourse/ui-kit/d-expanding-text-area",
  "discourse/components/filter-input": "discourse/ui-kit/d-filter-input",
  "discourse/components/flash-message": "discourse/ui-kit/d-flash-message",
  "discourse/components/future-date-input":
    "discourse/ui-kit/d-future-date-input",
  "discourse/components/highlighted-code":
    "discourse/ui-kit/d-highlighted-code",
  "discourse/components/horizontal-overflow-nav":
    "discourse/ui-kit/d-horizontal-overflow-nav",
  "discourse/components/html-with-links": "discourse/ui-kit/d-html-with-links",
  "discourse/components/input-tip": "discourse/ui-kit/d-input-tip",
  "discourse/components/interpolated-translation":
    "discourse/ui-kit/d-interpolated-translation",
  "discourse/components/light-dark-img": "discourse/ui-kit/d-light-dark-img",
  "discourse/components/load-more": "discourse/ui-kit/d-load-more",
  "discourse/components/nav-item": "discourse/ui-kit/d-nav-item",
  "discourse/components/number-field": "discourse/ui-kit/d-number-field",
  "discourse/components/password-field": "discourse/ui-kit/d-password-field",
  "discourse/components/pick-files-button":
    "discourse/ui-kit/d-pick-files-button",
  "discourse/components/popup-input-tip": "discourse/ui-kit/d-popup-input-tip",
  "discourse/components/radio-button": "discourse/ui-kit/d-radio-button",
  "discourse/components/relative-date": "discourse/ui-kit/d-relative-date",
  "discourse/components/relative-time-picker":
    "discourse/ui-kit/d-relative-time-picker",
  "discourse/components/responsive-table":
    "discourse/ui-kit/d-responsive-table",
  "discourse/components/save-controls": "discourse/ui-kit/d-save-controls",
  "discourse/components/second-factor-input":
    "discourse/ui-kit/d-second-factor-input",
  "discourse/components/small-user-list": "discourse/ui-kit/d-small-user-list",
  "discourse/components/table-header-toggle":
    "discourse/ui-kit/d-table-header-toggle",
  "discourse/components/tap-tile": "discourse/ui-kit/d-tap-tile",
  "discourse/components/tap-tile-grid": "discourse/ui-kit/d-tap-tile-grid",
  "discourse/components/text-field": "discourse/ui-kit/d-text-field",
  "discourse/components/textarea": "discourse/ui-kit/d-textarea",
  "discourse/components/time-input": "discourse/ui-kit/d-time-input",
  "discourse/components/time-shortcut-picker":
    "discourse/ui-kit/d-time-shortcut-picker",
  "discourse/components/toggle-password-mask":
    "discourse/ui-kit/d-toggle-password-mask",
  "discourse/components/user-avatar": "discourse/ui-kit/d-user-avatar",
  "discourse/components/user-avatar-flair":
    "discourse/ui-kit/d-user-avatar-flair",
  "discourse/components/user-info": "discourse/ui-kit/d-user-info",
  "discourse/components/user-link": "discourse/ui-kit/d-user-link",
  "discourse/components/user-stat": "discourse/ui-kit/d-user-stat",
  "discourse/components/user-status-message":
    "discourse/ui-kit/d-user-status-message",

  // Helpers
  "discourse/helpers/d-icon": "discourse/ui-kit/helpers/d-icon",
  "discourse/helpers/age-with-tooltip":
    "discourse/ui-kit/helpers/d-age-with-tooltip",
  "discourse/helpers/avatar": "discourse/ui-kit/helpers/d-avatar",
  "discourse/helpers/base-path": "discourse/ui-kit/helpers/d-base-path",
  "discourse/helpers/bound-avatar": "discourse/ui-kit/helpers/d-bound-avatar",
  "discourse/helpers/bound-avatar-template":
    "discourse/ui-kit/helpers/d-bound-avatar-template",
  "discourse/helpers/bound-category-link":
    "discourse/ui-kit/helpers/d-bound-category-link",
  "discourse/helpers/category-badge":
    "discourse/ui-kit/helpers/d-category-badge",
  "discourse/helpers/category-link": "discourse/ui-kit/helpers/d-category-link",
  "discourse/helpers/concat-class": "discourse/ui-kit/helpers/d-concat-class",
  "discourse/helpers/dasherize": "discourse/ui-kit/helpers/d-dasherize",
  "discourse/helpers/dir-span": "discourse/ui-kit/helpers/d-dir-span",
  "discourse/helpers/discourse-tag": "discourse/ui-kit/helpers/d-discourse-tag",
  "discourse/helpers/discourse-tags":
    "discourse/ui-kit/helpers/d-discourse-tags",
  "discourse/helpers/element": "discourse/ui-kit/helpers/d-element",
  "discourse/helpers/emoji": "discourse/ui-kit/helpers/d-emoji",
  "discourse/helpers/format-date": "discourse/ui-kit/helpers/d-format-date",
  "discourse/helpers/format-duration":
    "discourse/ui-kit/helpers/d-format-duration",
  "discourse/helpers/icon-or-image": "discourse/ui-kit/helpers/d-icon-or-image",
  "discourse/helpers/loading-spinner":
    "discourse/ui-kit/helpers/d-loading-spinner",
  "discourse/helpers/number": "discourse/ui-kit/helpers/d-number",
  "discourse/helpers/replace-emoji": "discourse/ui-kit/helpers/d-replace-emoji",
  "discourse/helpers/topic-link": "discourse/ui-kit/helpers/d-topic-link",
  "discourse/helpers/unique-id": "discourse/ui-kit/helpers/d-unique-id",
  "discourse/helpers/user-avatar": "discourse/ui-kit/helpers/d-user-avatar",

  // Modifiers
  "discourse/modifiers/d-autocomplete":
    "discourse/ui-kit/modifiers/d-autocomplete",
  "discourse/modifiers/auto-focus": "discourse/ui-kit/modifiers/d-auto-focus",
  "discourse/modifiers/close-on-click-outside":
    "discourse/ui-kit/modifiers/d-close-on-click-outside",
  "discourse/modifiers/draggable": "discourse/ui-kit/modifiers/d-draggable",
  "discourse/modifiers/observe-intersection":
    "discourse/ui-kit/modifiers/d-observe-intersection",
  "discourse/modifiers/on-resize": "discourse/ui-kit/modifiers/d-on-resize",
  "discourse/modifiers/scroll-into-view":
    "discourse/ui-kit/modifiers/d-scroll-into-view",
  "discourse/modifiers/swipe": "discourse/ui-kit/modifiers/d-swipe",
  "discourse/modifiers/tab-to-sibling":
    "discourse/ui-kit/modifiers/d-tab-to-sibling",
  "discourse/modifiers/trap-tab": "discourse/ui-kit/modifiers/d-trap-tab",
};

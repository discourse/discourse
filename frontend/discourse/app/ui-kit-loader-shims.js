import { importSync } from "@embroider/macros";
import loaderShim from "discourse/lib/loader-shim";

/* Components */
loaderShim("discourse/components/async-content", () =>
  importSync("discourse/ui-kit/d-async-content")
);
loaderShim("discourse/components/avatar-flair", () =>
  importSync("discourse/ui-kit/d-avatar-flair")
);
loaderShim("discourse/components/badge-button", () =>
  importSync("discourse/ui-kit/d-badge-button")
);
loaderShim("discourse/components/badge-card", () =>
  importSync("discourse/ui-kit/d-badge-card")
);
loaderShim("discourse/components/badge-title", () =>
  importSync("discourse/ui-kit/d-badge-title")
);
loaderShim("discourse/components/calendar-date-time-input", () =>
  importSync("discourse/ui-kit/d-calendar-date-time-input")
);
loaderShim("discourse/components/card-container", () =>
  importSync("discourse/ui-kit/d-card-container")
);
loaderShim("discourse/components/cdn-img", () =>
  importSync("discourse/ui-kit/d-cdn-img")
);
loaderShim("discourse/components/conditional-in-element", () =>
  importSync("discourse/ui-kit/d-conditional-in-element")
);
loaderShim("discourse/components/conditional-loading-section", () =>
  importSync("discourse/ui-kit/d-conditional-loading-section")
);
loaderShim("discourse/components/conditional-loading-spinner", () =>
  importSync("discourse/ui-kit/d-conditional-loading-spinner")
);
loaderShim("discourse/components/cook-text", () =>
  importSync("discourse/ui-kit/d-cook-text")
);
loaderShim("discourse/components/copy-button", () =>
  importSync("discourse/ui-kit/d-copy-button")
);
loaderShim("discourse/components/count-i18n", () =>
  importSync("discourse/ui-kit/d-count-i18n")
);
loaderShim("discourse/components/custom-html", () =>
  importSync("discourse/ui-kit/d-custom-html")
);
loaderShim("discourse/components/d-autocomplete-results", () =>
  importSync("discourse/ui-kit/d-autocomplete-results")
);
loaderShim("discourse/components/d-breadcrumbs-container", () =>
  importSync("discourse/ui-kit/d-breadcrumbs-container")
);
loaderShim("discourse/components/d-breadcrumbs-item", () =>
  importSync("discourse/ui-kit/d-breadcrumbs-item")
);
loaderShim("discourse/components/d-button", () =>
  importSync("discourse/ui-kit/d-button")
);
loaderShim("discourse/components/d-combo-button", () =>
  importSync("discourse/ui-kit/d-combo-button")
);
loaderShim("discourse/components/d-editor", () =>
  importSync("discourse/ui-kit/d-editor/d-editor")
);
loaderShim("discourse/components/d-editor-original-translation-preview", () =>
  importSync("discourse/ui-kit/d-editor/d-editor-original-translation-preview")
);
loaderShim("discourse/components/d-editor-preview", () =>
  importSync("discourse/ui-kit/d-editor/d-editor-preview")
);
loaderShim("discourse/components/d-modal", () =>
  importSync("discourse/ui-kit/d-modal/d-modal")
);
loaderShim("discourse/components/d-modal-cancel", () =>
  importSync("discourse/ui-kit/d-modal/d-modal-cancel")
);
loaderShim("discourse/components/d-multi-select", () =>
  importSync("discourse/ui-kit/d-multi-select")
);
loaderShim("discourse/components/d-navigation", () =>
  importSync("discourse/ui-kit/d-navigation")
);
loaderShim("discourse/components/d-navigation-item", () =>
  importSync("discourse/ui-kit/d-navigation-item")
);
loaderShim("discourse/components/d-otp/index", () =>
  importSync("discourse/ui-kit/d-otp/index")
);
loaderShim("discourse/components/d-otp/slot", () =>
  importSync("discourse/ui-kit/d-otp/slot")
);
loaderShim("discourse/components/d-page-action-button", () =>
  importSync("discourse/ui-kit/d-page-action-button")
);
loaderShim("discourse/components/d-page-header", () =>
  importSync("discourse/ui-kit/d-page-header")
);
loaderShim("discourse/components/d-page-subheader", () =>
  importSync("discourse/ui-kit/d-page-subheader")
);
loaderShim("discourse/components/d-section", () =>
  importSync("discourse/ui-kit/d-section")
);
loaderShim("discourse/components/d-select", () =>
  importSync("discourse/ui-kit/d-select")
);
loaderShim("discourse/components/d-stat-tiles", () =>
  importSync("discourse/ui-kit/d-stat-tiles")
);
loaderShim("discourse/components/d-toggle-switch", () =>
  importSync("discourse/ui-kit/d-toggle-switch")
);
loaderShim("discourse/components/date-input", () =>
  importSync("discourse/ui-kit/d-date-input")
);
loaderShim("discourse/components/date-picker", () =>
  importSync("discourse/ui-kit/d-date-picker/d-date-picker")
);
loaderShim("discourse/components/date-picker-future", () =>
  importSync("discourse/ui-kit/d-date-picker/d-date-picker-future")
);
loaderShim("discourse/components/date-picker-past", () =>
  importSync("discourse/ui-kit/d-date-picker/d-date-picker-past")
);
loaderShim("discourse/components/date-time-input", () =>
  importSync("discourse/ui-kit/d-date-time-input")
);
loaderShim("discourse/components/date-time-input-range", () =>
  importSync("discourse/ui-kit/d-date-time-input-range")
);
loaderShim("discourse/components/decorated-html", () =>
  importSync("discourse/ui-kit/d-decorated-html")
);
loaderShim("discourse/components/deferred-render", () =>
  importSync("discourse/ui-kit/d-deferred-render")
);
loaderShim("discourse/components/directory-table", () =>
  importSync("discourse/ui-kit/d-directory-table")
);
loaderShim("discourse/components/discourse-banner", () =>
  importSync("discourse/ui-kit/d-discourse-banner")
);
loaderShim("discourse/components/dropdown-menu", () =>
  importSync("discourse/ui-kit/d-dropdown-menu")
);
loaderShim("discourse/components/empty-state", () =>
  importSync("discourse/ui-kit/d-empty-state")
);
loaderShim("discourse/components/filter-input", () =>
  importSync("discourse/ui-kit/d-filter-input")
);
loaderShim("discourse/components/flash-message", () =>
  importSync("discourse/ui-kit/d-flash-message")
);
loaderShim("discourse/components/footer-nav", () =>
  importSync("discourse/ui-kit/d-footer-nav")
);
loaderShim("discourse/components/future-date-input", () =>
  importSync("discourse/ui-kit/d-future-date-input")
);
loaderShim("discourse/components/global-notice", () =>
  importSync("discourse/ui-kit/d-global-notice")
);
loaderShim("discourse/components/highlighted-code", () =>
  importSync("discourse/ui-kit/d-highlighted-code")
);
loaderShim("discourse/components/horizontal-overflow-nav", () =>
  importSync("discourse/ui-kit/d-horizontal-overflow-nav")
);
loaderShim("discourse/components/html-with-links", () =>
  importSync("discourse/ui-kit/d-html-with-links")
);
loaderShim("discourse/components/input-tip", () =>
  importSync("discourse/ui-kit/d-input-tip")
);
loaderShim("discourse/components/interpolated-translation", () =>
  importSync("discourse/ui-kit/d-interpolated-translation")
);
loaderShim("discourse/components/light-dark-img", () =>
  importSync("discourse/ui-kit/d-light-dark-img")
);
loaderShim("discourse/components/load-more", () =>
  importSync("discourse/ui-kit/d-load-more")
);
loaderShim("discourse/components/nav-item", () =>
  importSync("discourse/ui-kit/d-nav-item")
);
loaderShim("discourse/components/navigation-bar", () =>
  importSync("discourse/ui-kit/d-navigation-bar")
);
loaderShim("discourse/components/navigation-item", () =>
  importSync("discourse/ui-kit/d-navigation-filter-item")
);
loaderShim("discourse/components/page-loading-slider", () =>
  importSync("discourse/ui-kit/d-page-loading-slider")
);
loaderShim("discourse/components/pick-files-button", () =>
  importSync("discourse/ui-kit/d-pick-files-button")
);
loaderShim("discourse/components/popup-input-tip", () =>
  importSync("discourse/ui-kit/d-popup-input-tip")
);
loaderShim("discourse/components/relative-date", () =>
  importSync("discourse/ui-kit/d-relative-date")
);
loaderShim("discourse/components/relative-time-picker", () =>
  importSync("discourse/ui-kit/d-relative-time-picker")
);
loaderShim("discourse/components/responsive-table", () =>
  importSync("discourse/ui-kit/d-responsive-table")
);
loaderShim("discourse/components/save-controls", () =>
  importSync("discourse/ui-kit/d-save-controls")
);
loaderShim("discourse/components/second-factor-input", () =>
  importSync("discourse/ui-kit/d-second-factor-input")
);
loaderShim("discourse/components/small-user-list", () =>
  importSync("discourse/ui-kit/d-small-user-list")
);
loaderShim("discourse/components/table-header-toggle", () =>
  importSync("discourse/ui-kit/d-table-header-toggle")
);
loaderShim("discourse/components/tap-tile", () =>
  importSync("discourse/ui-kit/d-tap-tile")
);
loaderShim("discourse/components/tap-tile-grid", () =>
  importSync("discourse/ui-kit/d-tap-tile-grid")
);
loaderShim("discourse/components/textarea", () =>
  importSync("discourse/ui-kit/d-textarea")
);
loaderShim("discourse/components/time-input", () =>
  importSync("discourse/ui-kit/d-time-input")
);
loaderShim("discourse/components/time-shortcut-picker", () =>
  importSync("discourse/ui-kit/d-time-shortcut-picker")
);
loaderShim("discourse/components/toggle-password-mask", () =>
  importSync("discourse/ui-kit/d-toggle-password-mask")
);
loaderShim("discourse/components/user-avatar", () =>
  importSync("discourse/ui-kit/d-user-avatar")
);
loaderShim("discourse/components/user-avatar-flair", () =>
  importSync("discourse/ui-kit/d-user-avatar-flair")
);
loaderShim("discourse/components/user-info", () =>
  importSync("discourse/ui-kit/d-user-info")
);
loaderShim("discourse/components/user-link", () =>
  importSync("discourse/ui-kit/d-user-link")
);
loaderShim("discourse/components/user-stat", () =>
  importSync("discourse/ui-kit/d-user-stat")
);
loaderShim("discourse/components/user-status-message", () =>
  importSync("discourse/ui-kit/d-user-status-message")
);

/* Helpers */
loaderShim("discourse/helpers/age-with-tooltip", () =>
  importSync("discourse/ui-kit/helpers/d-age-with-tooltip")
);
loaderShim("discourse/helpers/avatar", () =>
  importSync("discourse/ui-kit/helpers/d-avatar")
);
loaderShim("discourse/helpers/base-path", () =>
  importSync("discourse/ui-kit/helpers/d-base-path")
);
loaderShim("discourse/helpers/base-url", () =>
  importSync("discourse/ui-kit/helpers/d-base-url")
);
loaderShim("discourse/helpers/bound-avatar", () =>
  importSync("discourse/ui-kit/helpers/d-bound-avatar")
);
loaderShim("discourse/helpers/bound-avatar-template", () =>
  importSync("discourse/ui-kit/helpers/d-bound-avatar-template")
);
loaderShim("discourse/helpers/bound-category-link", () =>
  importSync("discourse/ui-kit/helpers/d-bound-category-link")
);
loaderShim("discourse/helpers/capitalize-string", () =>
  importSync("discourse/ui-kit/helpers/d-capitalize-string")
);
loaderShim("discourse/helpers/category-badge", () =>
  importSync("discourse/ui-kit/helpers/d-category-badge")
);
loaderShim("discourse/helpers/category-link", () =>
  importSync("discourse/ui-kit/helpers/d-category-link")
);
loaderShim("discourse/helpers/concat-class", () =>
  importSync("discourse/ui-kit/helpers/d-concat-class")
);
loaderShim("discourse/helpers/d-icon", () =>
  importSync("discourse/ui-kit/helpers/d-icon")
);
loaderShim("discourse/helpers/dasherize", () =>
  importSync("discourse/ui-kit/helpers/d-dasherize")
);
loaderShim("discourse/helpers/dir-span", () =>
  importSync("discourse/ui-kit/helpers/d-dir-span")
);
loaderShim("discourse/helpers/discourse-tag", () =>
  importSync("discourse/ui-kit/helpers/d-discourse-tag")
);
loaderShim("discourse/helpers/discourse-tags", () =>
  importSync("discourse/ui-kit/helpers/d-discourse-tags")
);
loaderShim("discourse/helpers/element", () =>
  importSync("discourse/ui-kit/helpers/d-element")
);
loaderShim("discourse/helpers/emoji", () =>
  importSync("discourse/ui-kit/helpers/d-emoji")
);
loaderShim("discourse/helpers/format-age", () =>
  importSync("discourse/ui-kit/helpers/d-format-age")
);
loaderShim("discourse/helpers/format-date", () =>
  importSync("discourse/ui-kit/helpers/d-format-date")
);
loaderShim("discourse/helpers/format-duration", () =>
  importSync("discourse/ui-kit/helpers/d-format-duration")
);
loaderShim("discourse/helpers/get-url", () =>
  importSync("discourse/ui-kit/helpers/d-get-url")
);
loaderShim("discourse/helpers/html-safe", () =>
  importSync("discourse/ui-kit/helpers/d-html-safe")
);
loaderShim("discourse/helpers/i18n", () =>
  importSync("discourse/ui-kit/helpers/d-i18n")
);
loaderShim("discourse/helpers/icon-or-image", () =>
  importSync("discourse/ui-kit/helpers/d-icon-or-image")
);
loaderShim("discourse/helpers/inline-date", () =>
  importSync("discourse/ui-kit/helpers/d-inline-date")
);
loaderShim("discourse/helpers/loading-spinner", () =>
  importSync("discourse/ui-kit/helpers/d-loading-spinner")
);
loaderShim("discourse/helpers/number", () =>
  importSync("discourse/ui-kit/helpers/d-number")
);
loaderShim("discourse/helpers/replace-emoji", () =>
  importSync("discourse/ui-kit/helpers/d-replace-emoji")
);
loaderShim("discourse/helpers/topic-link", () =>
  importSync("discourse/ui-kit/helpers/d-topic-link")
);
loaderShim("discourse/helpers/unique-id", () =>
  importSync("discourse/ui-kit/helpers/d-unique-id")
);
loaderShim("discourse/helpers/user-avatar", () =>
  importSync("discourse/ui-kit/helpers/d-user-avatar")
);

/* Modifiers */
loaderShim("discourse/modifiers/auto-focus", () =>
  importSync("discourse/ui-kit/modifiers/d-auto-focus")
);
loaderShim("discourse/modifiers/close-on-click-outside", () =>
  importSync("discourse/ui-kit/modifiers/d-close-on-click-outside")
);
loaderShim("discourse/modifiers/d-autocomplete", () =>
  importSync("discourse/ui-kit/modifiers/d-autocomplete")
);
loaderShim("discourse/modifiers/draggable", () =>
  importSync("discourse/ui-kit/modifiers/d-draggable")
);
loaderShim("discourse/modifiers/observe-intersection", () =>
  importSync("discourse/ui-kit/modifiers/d-observe-intersection")
);
loaderShim("discourse/modifiers/on-resize", () =>
  importSync("discourse/ui-kit/modifiers/d-on-resize")
);
loaderShim("discourse/modifiers/scroll-into-view", () =>
  importSync("discourse/ui-kit/modifiers/d-scroll-into-view")
);
loaderShim("discourse/modifiers/swipe", () =>
  importSync("discourse/ui-kit/modifiers/d-swipe")
);
loaderShim("discourse/modifiers/tab-to-sibling", () =>
  importSync("discourse/ui-kit/modifiers/d-tab-to-sibling")
);
loaderShim("discourse/modifiers/trap-tab", () =>
  importSync("discourse/ui-kit/modifiers/d-trap-tab")
);

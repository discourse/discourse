import Component from "@glimmer/component";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import SearchMenu from "discourse/components/search-menu";
import bodyClass from "discourse/helpers/body-class";
import getURL from "discourse/lib/get-url";
import { headerOffset } from "discourse/lib/offset-calculator";
import { applyValueTransformer } from "discourse/lib/transformer";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";

/**
 * The welcome banner's search input. While any of it shows below the header it
 * is the page's search, and the header search steps aside; scrolling it away
 * hands search (and focus) back to the header.
 *
 * @param {string} [placeholder] - Translation key for the input's placeholder.
 * @param {string} [translatedPlaceholder] - Placeholder text, used as-is.
 */
export default class WelcomeBannerSearch extends Component {
  @service appEvents;
  @service search;

  checkViewport = modifier((element) => {
    const checkVisibility = () => {
      // Use getBoundingClientRect for reliable visibility detection.
      // IntersectionObserver's isIntersecting can return stale values during
      // SPA navigation, but getBoundingClientRect is always accurate.
      // The banner search stays the only visible search bar while any part of
      // it peeks below the header; the header search replaces it exactly when
      // it is fully tucked away, so the two are never both usable.
      const isUsable = element.getBoundingClientRect().bottom > headerOffset();

      const previousInputId = this.search.currentSearchInputId;
      this.search.welcomeBannerSearchInViewport = isUsable;

      if (
        this.search.currentSearchInputId !== previousInputId &&
        document.activeElement?.id === previousInputId
      ) {
        next(() => {
          if (this.isDestroying) {
            return;
          }
          this.search.focusSearchInput();
          if (document.activeElement?.tagName !== "INPUT") {
            document.getElementById(previousInputId)?.focus();
          }
        });
      }
    };

    // Use IntersectionObserver only as a trigger for when to check visibility,
    // not to determine actual visibility state. The handoff happens partway
    // through the input's crossing, so trigger throughout the crossing rather
    // than only at full visibility.
    const threshold = Array.from({ length: 101 }, (_, i) => i / 100);
    const observer = new IntersectionObserver(checkVisibility, { threshold });
    observer.observe(element);

    // The banner sits at the top of the page, so it starts out in view.
    this.search.welcomeBannerSearchInViewport = true;

    return () => {
      observer.disconnect();
      this.search.welcomeBannerSearchInViewport = false;
    };
  });

  handoffFocus = modifier((element) => {
    const onFocusin = (event) => {
      if (event.target.id !== "welcome-banner-search-input") {
        return;
      }

      const activeInput = document.getElementById(
        this.search.currentSearchInputId
      );
      if (activeInput && activeInput !== event.target) {
        activeInput.focus();
      }
    };

    element.addEventListener("focusin", onFocusin);
    return () => element.removeEventListener("focusin", onFocusin);
  });

  handleKeyboardShortcut = modifier(() => {
    const cb = (appEvent) => {
      if (
        appEvent.type === "search" &&
        this.search.welcomeBannerSearchInViewport
      ) {
        this.search.focusSearchInput();
        appEvent.event.preventDefault();
      }
    };
    this.appEvents.on("header:keyboard-trigger", cb);
    return () => this.appEvents.off("header:keyboard-trigger", cb);
  });

  // The icon is a shortcut to advanced search; a consumer that has made the
  // input mean more than searching can drop it.
  get showAdvancedSearchIcon() {
    return applyValueTransformer("search-advanced-icon-enabled", true, {
      location: "welcome-banner",
    });
  }

  get bodyClasses() {
    return this.search.welcomeBannerSearchInViewport
      ? "welcome-banner--visible"
      : "";
  }

  <template>
    {{bodyClass this.bodyClasses}}
    <div
      class="search-menu welcome-banner__search-menu"
      {{this.checkViewport}}
      {{this.handoffFocus}}
      {{this.handleKeyboardShortcut}}
    >
      {{#if this.showAdvancedSearchIcon}}
        <DButton
          class="search-icon"
          @href={{getURL "/search?expanded=true"}}
          @icon="magnifying-glass"
          @title="search.open_advanced"
        />
      {{/if}}
      <SearchMenu
        @hideResults={{not this.search.welcomeBannerSearchInViewport}}
        @location="welcome-banner"
        @searchInputId="welcome-banner-search-input"
        @searchInputPlaceholder={{@placeholder}}
        @translatedSearchInputPlaceholder={{@translatedPlaceholder}}
      />
    </div>
  </template>
}

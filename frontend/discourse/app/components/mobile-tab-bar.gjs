import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import CreateButton from "discourse/components/mobile-tab-bar/create-button";
import MenuButton from "discourse/components/mobile-tab-bar/menu-button";
import MoreTab from "discourse/components/mobile-tab-bar/more-tab";
import Tab from "discourse/components/mobile-tab-bar/tab";
import htmlClass from "discourse/helpers/html-class";
import discourseLater from "discourse/lib/later";
import { SCROLLED_DOWN } from "discourse/services/scroll-direction";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

// How long a tapped view holds the highlight before the current one takes it
// back, if its navigation never completes
const PENDING_VIEW_TIMEOUT = 3000;

export default class MobileTabBar extends Component {
  @service composer;
  @service mobileTabBar;
  @service scrollDirection;

  #track = null;
  #pendingView = null;
  #pendingViewTimer = null;
  #viewsKey = null;
  #views = null;
  #viewsFrame = null;
  #viewsMutations = null;
  #viewsObserver = null;

  // Moves the highlight as soon as a view is tapped, rather than once its
  // list has loaded, so it slides while the page is idle
  #previewViewsHighlight = (event) => {
    const link = event.target.closest?.(".nav-pills a");

    if (link && this.#views?.contains(link)) {
      this.#pendingView = {
        href: link.getAttribute("href"),
        until: Date.now() + PENDING_VIEW_TIMEOUT,
      };
      this.#placeViewsHighlight();

      cancel(this.#pendingViewTimer);
      this.#pendingViewTimer = discourseLater(
        this.#queueViewsHighlight,
        PENDING_VIEW_TIMEOUT
      );
    }
  };

  #queueViewsHighlight = () => {
    cancelAnimationFrame(this.#viewsFrame);
    this.#viewsFrame = requestAnimationFrame(() => this.#placeViewsHighlight());
  };

  get isVisible() {
    return this.mobileTabBar.enabled && !this.composer.isOpen;
  }

  // Out of the way while reading down a page, back on the way up. A page
  // too short to scroll never counts as scrolled down, so it keeps them.
  get viewsTucked() {
    return this.scrollDirection.lastScrollDirection === SCROLLED_DOWN;
  }

  @action
  registerViewsSlot(element) {
    this.mobileTabBar.viewsSlot = element;
    this.#views = element;

    // The controls follow the viewport, which moves the tab it points at
    this.#viewsObserver = new ResizeObserver(() => {
      this.#placeTabHighlight();
      this.#pointAtActiveTab();
      this.#queueViewsHighlight();
    });
    this.#viewsObserver.observe(element.nextElementSibling);
    this.#viewsObserver.observe(element);

    // Sections render their views here, so watch for the current one changing,
    // and for a list of them scrolling to or from its edges
    this.#viewsMutations = new MutationObserver(this.#queueViewsHighlight);
    this.#viewsMutations.observe(element, {
      attributeFilter: [
        "class",
        "data-d-scroll-at-start",
        "data-d-scroll-at-end",
        "data-d-scroll-overflow",
      ],
      childList: true,
      subtree: true,
    });
    element.addEventListener("scroll", this.#queueViewsHighlight, {
      capture: true,
      passive: true,
    });
    element.addEventListener("click", this.#previewViewsHighlight, {
      capture: true,
    });
  }

  @action
  unregisterViewsSlot() {
    this.#viewsObserver?.disconnect();
    this.#viewsObserver = null;
    this.#viewsMutations?.disconnect();
    this.#viewsMutations = null;
    cancelAnimationFrame(this.#viewsFrame);
    this.#views?.removeEventListener("scroll", this.#queueViewsHighlight, {
      capture: true,
    });
    this.#views?.removeEventListener("click", this.#previewViewsHighlight, {
      capture: true,
    });
    cancel(this.#pendingViewTimer);
    this.#pendingView = null;
    this.#views = null;
    this.#viewsKey = null;
    this.mobileTabBar.viewsSlot = null;
  }

  @action
  followActiveTab(track) {
    this.#track = track;
    this.#placeTabHighlight();
    this.#pointAtActiveTab();
  }

  // Moves the highlight under the current section's tab: instantly the first
  // time, so it doesn't slide in from the edge, then sliding
  #placeTabHighlight() {
    const track = this.#track;
    const tab = track?.querySelector(".mobile-tab-bar__tab.--active");

    if (!tab) {
      return;
    }

    track.style.setProperty(
      "--mobile-tab-bar-highlight-x",
      `${tab.offsetLeft}px`
    );
    track.style.setProperty(
      "--mobile-tab-bar-highlight-width",
      `${tab.offsetWidth}px`
    );

    if (!("sliding" in track.dataset)) {
      requestAnimationFrame(() => (track.dataset.sliding = ""));
    }
  }

  // Moves the views' highlight under the current view. Jumps rather than
  // slides to a different set of views, as between sections; a list
  // re-rendering the same views still slides.
  #placeViewsHighlight() {
    const views = this.#views;
    const active =
      this.#pendingViewLink() ?? views?.querySelector(".nav-pills a.active");

    // Keeps its size while no view is current, as when a list re-renders, or
    // the current one is scrolled out of plain sight, so it doesn't collapse
    // and regrow
    if (!active) {
      views?.style.setProperty("--mobile-tab-bar-views-highlight-opacity", "0");
      return;
    }

    // Kept to the part of the views in plain sight: inside the bubble, and
    // clear of the faded edges with more views past them
    const box = views.getBoundingClientRect();
    const rect = active.getBoundingClientRect();
    const [start, end] = this.#viewsInSight(active.closest(".nav-pills"), box);
    const left = Math.max(rect.left, start) - box.left;
    const right = Math.min(rect.right, end) - box.left;
    const inSight = right - left >= rect.height;

    views.style.setProperty(
      "--mobile-tab-bar-views-highlight-opacity",
      inSight ? "1" : "0"
    );

    if (!inSight) {
      return;
    }

    const key = [...views.querySelectorAll(".nav-pills a")]
      .map((link) => link.getAttribute("href"))
      .join(" ");
    const jump = key !== this.#viewsKey;
    this.#viewsKey = key;

    if (jump) {
      delete views.dataset.sliding;
    }

    views.style.setProperty("--mobile-tab-bar-views-highlight-x", `${left}px`);
    views.style.setProperty(
      "--mobile-tab-bar-views-highlight-y",
      `${rect.top - box.top}px`
    );
    const width = Math.max(rect.height, right - left);
    views.style.setProperty(
      "--mobile-tab-bar-views-highlight-width",
      `${width}px`
    );
    views.style.setProperty(
      "--mobile-tab-bar-views-highlight-height",
      `${rect.height}px`
    );
    // Unitless, as the middle stretches with a scale between the caps
    views.style.setProperty(
      "--mobile-tab-bar-views-highlight-stretch",
      `${width - rect.height}`
    );

    if (jump) {
      requestAnimationFrame(() => (views.dataset.sliding = ""));
    }
  }

  // Where a list of views shows them unfaded, within the bubble. The fade
  // is as wide as the list's scroll padding, which keeps scrolled-to views
  // clear of it too.
  #viewsInSight(list, box) {
    let start = box.left;
    let end = box.right;

    if (list?.hasAttribute("data-d-scroll-overflow")) {
      const rect = list.getBoundingClientRect();
      const fade = parseFloat(getComputedStyle(list).scrollPaddingLeft) || 0;
      start = Math.max(start, rect.left);
      end = Math.min(end, rect.right);

      if (!list.hasAttribute("data-d-scroll-at-start")) {
        start += fade;
      }

      if (!list.hasAttribute("data-d-scroll-at-end")) {
        end -= fade;
      }
    }

    return [start, end];
  }

  // The tapped view until its list shows it as current, or the navigation
  // gives up
  #pendingViewLink() {
    const pending = this.#pendingView;

    if (!pending || !this.#views || Date.now() > pending.until) {
      this.#pendingView = null;
      return null;
    }

    const links = [...this.#views.querySelectorAll(".nav-pills a")];
    const link = links.find((l) => l.getAttribute("href") === pending.href);

    if (!link || link.classList.contains("active")) {
      this.#pendingView = null;
      return null;
    }

    return link;
  }

  // Aims the views bubble's arrow at the current section's tab, by its
  // offset from the bar's centre, where the bubble is centred
  #pointAtActiveTab() {
    const tab = this.#track?.querySelector(".mobile-tab-bar__tab.--active");

    if (!tab || !this.#views) {
      return;
    }

    const bar = this.#views.nextElementSibling.getBoundingClientRect();
    const tabRect = tab.getBoundingClientRect();
    const offset =
      tabRect.left + tabRect.width / 2 - (bar.left + bar.width / 2);

    this.#views.style.setProperty(
      "--mobile-tab-bar-pointer-offset",
      `${offset}px`
    );
  }

  <template>
    {{#if this.isVisible}}
      {{htmlClass "footer-nav-visible" "mobile-tab-bar-visible"}}
      {{#if this.mobileTabBar.isNestedPage}}
        {{htmlClass "mobile-tab-bar-nested"}}
      {{/if}}
      {{#if this.mobileTabBar.isTitledPage}}
        {{htmlClass "mobile-tab-bar-titled"}}
      {{/if}}

      <nav
        aria-label={{i18n "mobile_tab_bar.label"}}
        class={{dConcatClass
          "mobile-tab-bar"
          (if this.viewsTucked "--views-tucked")
          (unless this.mobileTabBar.sectionTabKey "--no-section")
        }}
      >
        <div
          class="mobile-tab-bar__views"
          {{didInsert this.registerViewsSlot}}
          {{willDestroy this.unregisterViewsSlot}}
        ><span aria-hidden="true" class="mobile-tab-bar__views-highlight"><span
              class="mobile-tab-bar__views-highlight-middle"
            ></span></span></div>
        <div class="mobile-tab-bar__controls">
          <MenuButton />
          <div class="mobile-tab-bar__tabs">
            <div
              class="mobile-tab-bar__track"
              {{didInsert this.followActiveTab}}
              {{didUpdate
                this.followActiveTab
                this.mobileTabBar.sectionTabKey
                this.mobileTabBar.barTabs
              }}
            >
              <span aria-hidden="true" class="mobile-tab-bar__highlight"></span>
              {{#each this.mobileTabBar.barTabs key="key" as |tab|}}
                <Tab @tab={{tab}} />
              {{/each}}
              {{#if this.mobileTabBar.moreTabs.length}}
                <MoreTab />
              {{/if}}
            </div>
          </div>
          <CreateButton @canSignUp={{@canSignUp}} />
        </div>
      </nav>
    {{/if}}
  </template>
}

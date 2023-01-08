import {
  ANIMATION_DURATION,
  KEYBOARD_SHORTCUTS,
  LAYOUT_TYPES,
  LIGHTBOX_APP_EVENT_NAMES,
  LIGHTBOX_ELEMENT_ID,
  SWIPE_DIRECTIONS,
  TITLE_ELEMENT_ID,
} from "discourse/lib/lightbox/constants";
import {
  createDownloadLink,
  getSwipeDirection,
  openImageInNewTab,
  preloadItemImages,
  scrollParentToElementCenter,
  setCarouselScrollPosition,
  setSiteThemeColor,
} from "discourse/lib/lightbox/helpers";

import Component from "@glimmer/component";
import { bind } from "discourse-common/utils/decorators";
import discourseLater from "discourse-common/lib/later";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class DLightbox extends Component {
  @service appEvents;

  @tracked callbacks = {};
  @tracked items = [];
  @tracked options = {};

  @tracked isVisible = false;
  @tracked isLoading = false;
  @tracked willClose = false;

  @tracked currentIndex = 0;
  @tracked currentItem = {};

  @tracked isZoomed = false;
  @tracked isRotated = false;
  @tracked isFullScreen = false;
  @tracked rotationAmount = 0;

  @tracked hasCarousel = false;
  @tracked hasExpandedTitle = false;

  elementId = LIGHTBOX_ELEMENT_ID;
  titleElementId = TITLE_ELEMENT_ID;
  animationDuration = ANIMATION_DURATION;

  get layoutType() {
    return window.innerWidth > window.innerHeight
      ? LAYOUT_TYPES.HORIZONTAL
      : LAYOUT_TYPES.VERTICAL;
  }

  get CSSVars() {
    const base = "--d-lightbox-image";

    const variables = [
      `${base}-animation-duration: ${this.animationDuration}ms;`,
    ];

    if (!this.currentItem) {
      return htmlSafe(variables.join(""));
    }

    const { width, height, aspectRatio, dominantColor, fullsizeURL, smallURL } =
      this.currentItem;

    variables.push(
      `${base}-rotation: ${this.rotationAmount}deg`,
      `${base}-width: ${width}px`,
      `${base}-height: ${height}px`,
      `${base}-aspect-ratio: ${aspectRatio}`,
      `${base}-dominant-color: #${dominantColor}`,
      `${base}-full-size-url: url(${fullsizeURL})`,
      `${base}-small-url: url(${smallURL})`
    );

    return htmlSafe(variables.filter(Boolean).join(";"));
  }

  get HTMLClassList() {
    const base = "d-lightbox";

    const classNames = [base];

    if (!this.isVisible) {
      return classNames.join("");
    }

    classNames.push(
      this.layoutType && `${base}--is-${this.layoutType}`,
      this.isVisible && `${base}--is-visible`,
      this.isLoading ? `${base}--is-loading` : `${base}--is-finished-loading`,
      this.isFullScreen && `${base}--is-fullscreen`,
      this.isZoomed && `${base}--is-zoomed`,
      this.isRotated && `${base}--is-rotated`,
      this.canZoom && `${base}--can-zoom`,
      this.hasExpandedTitle && `${base}--has-expanded-title`,
      this.hasCarousel && `${base}--has-carousel`,
      this.hasLoadingError && `${base}--has-loading-error`,
      this.willClose && `${base}--will-close`,
      this.isRotated &&
        this.rotationAmount &&
        `${base}--is-rotated-${this.rotationAmount}`
    );

    return classNames.filter(Boolean).join(" ");
  }

  get shouldDisplayMainImageArrows() {
    return (
      !this.options.isMobile &&
      this.canNavigate &&
      !this.hasCarousel &&
      !this.isZoomed &&
      !this.isRotated
    );
  }

  get shouldDisplayCarousel() {
    return this.hasCarousel && !this.isZoomed && !this.isRotated;
  }

  get shouldDisplayCarouselArrows() {
    return (
      !this.options.isMobile &&
      this.totalItemCount >= this.options.minCarosuelArrowItemCount
    );
  }

  get shouldDisplayTitle() {
    return !this.hasLoadingError && !this.isZoomed && !this.isRotated;
  }

  get totalItemCount() {
    return this.items?.length || 0;
  }

  get counterIndex() {
    return this.currentIndex ? this.currentIndex + 1 : 1;
  }

  get canNavigate() {
    return this.items?.length > 1;
  }

  get canZoom() {
    return !this.hasLoadingError && this.currentItem?.canZoom;
  }

  get canRotate() {
    return !this.hasLoadingError;
  }

  get canDownload() {
    return !this.hasLoadingError && this.options.canDownload;
  }

  get canFullscreen() {
    return !this.hasLoadingError;
  }

  get hasLoadingError() {
    return this.currentItem?.hasLoadingError;
  }

  get nextButtonIcon() {
    return this.options.isRTL ? "chevron-left" : "chevron-right";
  }

  get previousButtonIcon() {
    return this.options.isRTL ? "chevron-right" : "chevron-left";
  }

  get zoomButtonIcon() {
    return this.isZoomed ? "search-minus" : "search-plus";
  }

  @bind
  async registerAppEventListeners() {
    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.OPEN, this.open);
    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.CLOSE, this.close);
  }

  @bind
  async deregisterAppEventListners() {
    this.appEvents.off(LIGHTBOX_APP_EVENT_NAMES.OPEN, this.open);
    this.appEvents.off(LIGHTBOX_APP_EVENT_NAMES.CLOSE, this.close);
  }

  @bind
  async open({ items, startingIndex, callbacks, options }) {
    this.options = options;

    this.items = items;
    this.currentIndex = startingIndex;
    this.callbacks = callbacks;

    this.isLoading = true;
    this.isVisible = true;

    await this.#setCurrentItem(this.currentIndex);

    this.callbacks.onOpen?.({
      items: this.items,
      currentItem: this.currentItem,
    });
  }

  @bind
  async close() {
    this.willClose = true;

    discourseLater(this.cleanup, this.animationDuration);

    this.callbacks.onClose?.();
  }

  async #setCurrentItem(index) {
    await this.#onBeforeItemChange();

    this.currentIndex = (index + this.totalItemCount) % this.totalItemCount;
    this.currentItem = await preloadItemImages(this.items[this.currentIndex]);

    this.#onAfterItemChange();
  }

  async #onBeforeItemChange() {
    this.callbacks.onItemWillChange?.({
      currentItem: this.currentItem,
    });

    this.isLoading = true;
    this.isZoomed = false;
    this.isRotated = false;
  }

  async #onAfterItemChange() {
    this.isLoading = false;

    setSiteThemeColor(this.currentItem.dominantColor);

    setCarouselScrollPosition({
      behavior: "smooth",
    });

    this.callbacks.onItemDidChange?.({
      currentItem: this.currentItem,
    });

    const nextItem = this.items[this.currentIndex + 1];
    return nextItem ? preloadItemImages(nextItem) : false;
  }

  @bind
  async centerZoomedBackgroundPosition(zoomedImageContainer) {
    return this.options.isMobile
      ? scrollParentToElementCenter({
          element: zoomedImageContainer,
          isRTL: this.options.isRTL,
        })
      : false;
  }

  async zoomOnMouseover(event) {
    const zoomedImageContainer = event.target;

    const offsetX = event.offsetX;
    const offsetY = event.offsetY;

    const x = (offsetX / zoomedImageContainer.offsetWidth) * 100;
    const y = (offsetY / zoomedImageContainer.offsetHeight) * 100;

    zoomedImageContainer.style.backgroundPosition = x + "% " + y + "%";
  }

  @bind
  async toggleZoom() {
    if (this.isLoading || !this.canZoom) {
      return;
    }

    this.isZoomed = !this.isZoomed;
  }

  @bind
  async rotateImage() {
    this.rotationAmount = (this.rotationAmount + 90) % 360;
    this.isRotated = this.rotationAmount !== 0;
  }

  @bind
  async toggleFullScreen() {
    this.isFullScreen = !this.isFullScreen;

    return this.isFullScreen
      ? document.documentElement.requestFullscreen()
      : document.exitFullscreen();
  }

  @bind
  async downloadImage() {
    return createDownloadLink(this.currentItem);
  }

  @bind
  async openInNewTab() {
    return openImageInNewTab(this.currentItem);
  }

  @bind
  async reloadImage() {
    this.#setCurrentItem(this.currentIndex);
  }

  @bind
  async toggleCarousel() {
    this.hasCarousel = !this.hasCarousel;

    requestAnimationFrame(setCarouselScrollPosition);
  }

  @bind
  async showNextItem() {
    this.#setCurrentItem(this.currentIndex + 1);
  }

  @bind
  async showPreviousItem() {
    this.#setCurrentItem(this.currentIndex - 1);
  }

  @bind
  async showSelectedImage(event) {
    const targetIndex = event.target.dataset?.lightboxItemIndex;
    return targetIndex ? this.#setCurrentItem(Number(targetIndex)) : false;
  }

  @bind
  async toggleExpandTitle() {
    this.hasExpandedTitle = !this.hasExpandedTitle;
  }

  @bind
  async onKeyup({ key }) {
    if (KEYBOARD_SHORTCUTS.PREVIOUS.includes(key)) {
      return this.showPreviousItem();
    }

    if (KEYBOARD_SHORTCUTS.NEXT.includes(key)) {
      return this.showNextItem();
    }

    if (key === KEYBOARD_SHORTCUTS.CLOSE) {
      return this.close();
    }

    if (key === KEYBOARD_SHORTCUTS.ZOOM) {
      return this.toggleZoom();
    }

    if (key === KEYBOARD_SHORTCUTS.FULLSCREEN) {
      return this.toggleFullScreen();
    }

    if (key === KEYBOARD_SHORTCUTS.ROTATE) {
      return this.rotateImage();
    }

    if (key === KEYBOARD_SHORTCUTS.DOWNLOAD) {
      return this.downloadImage();
    }

    if (key === KEYBOARD_SHORTCUTS.CAROUSEL) {
      return this.toggleCarousel();
    }

    if (key === KEYBOARD_SHORTCUTS.TITLE) {
      return this.toggleExpandTitle();
    }

    if (key === KEYBOARD_SHORTCUTS.NEWTAB) {
      return this.openInNewTab();
    }
  }

  @bind
  async onTouchstart(event = Event) {
    if (this.isZoomed) {
      return false;
    }

    this.touchstartX = event.changedTouches[0].screenX;
    this.touchstartY = event.changedTouches[0].screenY;
  }

  @bind
  async onTouchend(event) {
    if (this.isZoomed) {
      return false;
    }

    event.stopPropagation();

    const touchendY = event.changedTouches[0].screenY;
    const touchendX = event.changedTouches[0].screenX;

    const swipeDirection = await getSwipeDirection({
      touchstartX: this.touchstartX,
      touchstartY: this.touchstartY,
      touchendX,
      touchendY,
    });

    switch (swipeDirection) {
      case SWIPE_DIRECTIONS.LEFT:
        this.options.isRTL ? this.showNextItem() : this.showPreviousItem();
        break;
      case SWIPE_DIRECTIONS.RIGHT:
        this.options.isRTL ? this.showPreviousItem() : this.showNextItem();
        break;
      case SWIPE_DIRECTIONS.UP:
        this.close();
        break;
      case SWIPE_DIRECTIONS.DOWN:
        this.toggleCarousel();
        break;
    }
  }

  @bind
  cleanup() {
    this.hasCarousel = false;
    this.hasExpandedTitle = false;
    this.isLoading = false;
    this.items = [];
    this.currentIndex = 0;
    this.isZoomed = false;
    this.isRotated = false;
    this.rotationAmount = 0;

    if (this.isFullScreen) {
      this.toggleFullScreen();
      this.isFullScreen = false;
    }

    this.isVisible = false;
    this.willClose = false;

    this.callbacks.onCleanup?.();

    this.callbacks = {};
    this.options = {};
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.cleanup();
  }
}

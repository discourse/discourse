import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
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
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";

export default class DLightbox extends Component {
  @service appEvents;

  @tracked items = [];
  @tracked isVisible = false;
  @tracked isLoading = false;
  @tracked currentIndex = 0;
  @tracked currentItem = {};

  @tracked isZoomed = false;
  @tracked isRotated = false;
  @tracked isFullScreen = false;
  @tracked rotationAmount = 0;

  @tracked hasCarousel = true;
  @tracked hasExpandedTitle = false;

  options = {};
  callbacks = {};
  willClose = false;
  elementId = LIGHTBOX_ELEMENT_ID;
  titleElementId = TITLE_ELEMENT_ID;
  animationDuration = ANIMATION_DURATION;
  scrollPosition = 0;

  willDestroy() {
    super.willDestroy(...arguments);
    this.cleanup();
  }

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

    const { width, height, aspectRatio, dominantColor, fullsizeURL } =
      this.currentItem;

    variables.push(
      `${base}-rotation: ${this.rotationAmount}deg`,
      `${base}-width: ${width}px`,
      `${base}-height: ${height}px`,
      `${base}-aspect-ratio: ${aspectRatio}`,
      `${base}-dominant-color: #${dominantColor}`,
      `${base}-full-size-url: url(${encodeURI(fullsizeURL)})`
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
      this.layoutType && `is-${this.layoutType}`,
      this.isVisible && `is-visible`,
      this.isLoading ? `is-loading` : `is-finished-loading`,
      this.isFullScreen && `is-fullscreen`,
      this.isZoomed && `is-zoomed`,
      this.isRotated && `is-rotated`,
      this.canZoom && `can-zoom`,
      this.hasExpandedTitle && `has-expanded-title`,
      this.hasCarousel && `has-carousel`,
      this.hasLoadingError && `has-loading-error`,
      this.willClose && `will-close`,
      this.isRotated &&
        this.rotationAmount &&
        `is-rotated-${this.rotationAmount}`
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
    return (
      this.hasCarousel &&
      this.totalItemCount >= this.options.minCarouselItemCount &&
      !this.isZoomed &&
      !this.isRotated
    );
  }

  get shouldDisplayCarouselArrows() {
    return (
      !this.options.isMobile &&
      this.totalItemCount >= this.options.minCarouselArrowItemCount
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
    return this.isZoomed ? "magnifying-glass-minus" : "magnifying-glass-plus";
  }

  @bind
  registerAppEventListeners() {
    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.OPEN, this.open);
    this.appEvents.on(LIGHTBOX_APP_EVENT_NAMES.CLOSE, this.close);
  }

  @bind
  deregisterAppEventListeners() {
    this.appEvents.off(LIGHTBOX_APP_EVENT_NAMES.OPEN, this.open);
    this.appEvents.off(LIGHTBOX_APP_EVENT_NAMES.CLOSE, this.close);
  }

  @bind
  open({ items, startingIndex, callbacks, options }) {
    this.options = options;

    this.items = items;
    this.currentIndex = startingIndex;
    this.callbacks = callbacks;

    this.isLoading = true;
    this.isVisible = true;
    this.scrollPosition = window.scrollY;

    this.#setCurrentItem(this.currentIndex);

    if (
      this.options.zoomOnOpen &&
      this.currentItem?.canZoom &&
      !this.currentItem?.isZoomed
    ) {
      this.toggleZoom();
    }

    this.callbacks.onOpen?.({
      items: this.items,
      currentItem: this.currentItem,
    });
  }

  @bind
  close() {
    this.willClose = true;

    discourseLater(this.cleanup, this.animationDuration);

    this.callbacks.onClose?.();
  }

  async #setCurrentItem(index) {
    this.#onBeforeItemChange();

    this.currentIndex = (index + this.totalItemCount) % this.totalItemCount;
    this.currentItem = await preloadItemImages(this.items[this.currentIndex]);

    this.#onAfterItemChange();
  }

  #onBeforeItemChange() {
    this.callbacks.onItemWillChange?.({
      currentItem: this.currentItem,
    });

    this.isLoading = true;
    this.isZoomed = false;
    this.isRotated = false;
  }

  #onAfterItemChange() {
    this.isLoading = false;

    if (this.currentItem.dominantColor) {
      setSiteThemeColor(this.currentItem.dominantColor);
    }

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
  centerZoomedBackgroundPosition(zoomedImageContainer) {
    return this.options.isMobile
      ? scrollParentToElementCenter({
          element: zoomedImageContainer,
          isRTL: this.options.isRTL,
        })
      : false;
  }

  zoomOnMouseover(event) {
    const zoomedImageContainer = event.target;

    const offsetX = event.offsetX;
    const offsetY = event.offsetY;

    const x = (offsetX / zoomedImageContainer.offsetWidth) * 100;
    const y = (offsetY / zoomedImageContainer.offsetHeight) * 100;

    zoomedImageContainer.style.backgroundPosition = x + "% " + y + "%";
  }

  @bind
  toggleZoom() {
    if (this.isLoading || !this.canZoom) {
      return;
    }

    this.isZoomed = !this.isZoomed;
    document.querySelector(".d-lightbox__close-button")?.focus();
  }

  @bind
  rotateImage() {
    this.rotationAmount = (this.rotationAmount + 90) % 360;
    this.isRotated = this.rotationAmount !== 0;
  }

  @bind
  toggleFullScreen() {
    this.isFullScreen = !this.isFullScreen;

    return this.isFullScreen
      ? document.documentElement.requestFullscreen()
      : document.exitFullscreen();
  }

  @bind
  downloadImage() {
    return createDownloadLink(this.currentItem);
  }

  @bind
  openInNewTab() {
    return openImageInNewTab(this.currentItem);
  }

  @bind
  reloadImage() {
    this.#setCurrentItem(this.currentIndex);
  }

  @bind
  toggleCarousel() {
    this.hasCarousel = !this.hasCarousel;

    requestAnimationFrame(setCarouselScrollPosition);
  }

  @bind
  showNextItem() {
    this.#setCurrentItem(this.currentIndex + 1);
  }

  @bind
  showPreviousItem() {
    this.#setCurrentItem(this.currentIndex - 1);
  }

  @bind
  showSelectedImage(event) {
    const targetIndex = event.target.dataset?.lightboxItemIndex;
    return targetIndex ? this.#setCurrentItem(Number(targetIndex)) : false;
  }

  @bind
  toggleExpandTitle() {
    this.hasExpandedTitle = !this.hasExpandedTitle;
  }

  @bind
  onKeydown(event) {
    if (event.key === KEYBOARD_SHORTCUTS.CLOSE) {
      event.preventDefault();
      event.stopPropagation();
      return this.close();
    }
  }

  @bind
  onKeyup({ key }) {
    if (KEYBOARD_SHORTCUTS.PREVIOUS.includes(key)) {
      return this.showPreviousItem();
    }

    if (KEYBOARD_SHORTCUTS.NEXT.includes(key)) {
      return this.showNextItem();
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
  onTouchstart(event = Event) {
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
      case SWIPE_DIRECTIONS.DOWN:
        this.close();
        break;
    }
  }

  @bind
  cleanup() {
    if (this.isVisible) {
      this.hasCarousel = true;
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

      this.resetScrollPosition();

      this.callbacks.onCleanup?.();

      this.callbacks = {};
      this.options = {};
    }
  }

  resetScrollPosition() {
    if (window.scrollY !== this.scrollPosition) {
      window.scrollTo({
        left: 0,
        top: parseInt(this.scrollPosition, 10),
        behavior: "instant",
      });
    }
  }
}

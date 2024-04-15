export default {
  async initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    if (siteSettings.enable_experimental_lightbox) {
      const viewportWidth = window.innerWidth;
      const bodyRects = document.body.getBoundingClientRect();
      let scrollbarWidth = viewportWidth - bodyRects.width;
      scrollbarWidth = scrollbarWidth = Math.round(scrollbarWidth * 100) / 100;

      document.documentElement.style.setProperty(
        "--document-scrollbar-width",
        `${scrollbarWidth}px`
      );
    }
  },
};

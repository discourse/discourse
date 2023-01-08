export default {
  name: "document-scrollbar-width",

  async initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

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

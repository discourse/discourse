export default {
  name: "ensure-image-dimensions",
  after: "mobile",
  initialize(container) {
    if (!window) {
      return;
    }

    // This enforces maximum dimensions of images based on site settings
    // for mobile we use the window width as a safeguard
    // This rule should never really be at play unless for some reason images do not have dimensions
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.enable_max_image_dimensions) {
      let width = siteSettings.max_image_width;
      let height = siteSettings.max_image_height;

      const site = container.lookup("site:main");
      if (site.mobileView) {
        width = $(window).width() - 20;
      }

      const style =
        "max-width:" + width + "px;" + "max-height:" + height + "px;";

      $(
        '<style id="image-sizing-hack">#reply-control .d-editor-preview img:not(.thumbnail):not(.ytp-thumbnail-image), .cooked img:not(.thumbnail):not(.ytp-thumbnail-image) {' +
          style +
          "}</style>"
      ).appendTo("head");
    }
  },
};

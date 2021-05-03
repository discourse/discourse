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
    let width = siteSettings.max_image_width;
    let height = siteSettings.max_image_height;

    const site = container.lookup("site:main");
    if (site.mobileView) {
      width = window.innerWidth - 20;
    }

    let styles = `max-width:${width}px; max-height:${height}px;`;

    if (siteSettings.disable_image_size_calculations) {
      styles = "max-width: 100%; height: auto;";
    }

    const styleTag = document.createElement("style");
    styleTag.id = "image-sizing-hack";
    styleTag.innerHTML = `#reply-control .d-editor-preview img:not(.thumbnail):not(.ytp-thumbnail-image):not(.emoji), .cooked img:not(.thumbnail):not(.ytp-thumbnail-image):not(.emoji) {${styles}}`;
    document.head.appendChild(styleTag);
  },
};

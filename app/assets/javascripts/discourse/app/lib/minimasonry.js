import loadScript from "discourse/lib/load-script";

export default function (elem, site) {
  if (!elem) {
    return;
  }

  const imageGrids = elem.querySelectorAll(
    '.auto-image-grid[data-auto-image-grid="on"]'
  );

  if (!imageGrids.length) {
    return;
  }

  loadScript("/javascripts/minimasonry.min.js").then(function () {
    // TODO: Ensure masonries are not initialized twice
    imageGrids.forEach((item) => {
      // eslint-disable-next-line no-undef
      new MiniMasonry({
        container: item,
        baseWidth: site.mobileView ? 140 : 200,
        surroundingGutter: false,
        gutterX: 5,
        gutterY: 5,
      }).layout();
    });
  });
}

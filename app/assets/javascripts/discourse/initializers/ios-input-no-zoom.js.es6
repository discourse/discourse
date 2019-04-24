// Prevents auto-zoom in Safari iOS inputs with font-size < 16px
const originalMeta = $("meta[name=viewport]").attr("content");

export default {
  name: "ios-input-no-zoom",

  initialize() {
    let iOS =
      !!navigator.platform && /iPad|iPhone|iPod/.test(navigator.platform);

    if (iOS) {
      $("body").on("touchstart", "input", () => {
        $("meta[name=viewport]").attr(
          "content",
          "width=device-width, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, user-scalable=no"
        );
      });

      $("body").on("focusout", "input", e => {
        if (e.relatedTarget === null) {
          $("meta[name=viewport]").attr("content", originalMeta);
        }
      });
    }
  }
};

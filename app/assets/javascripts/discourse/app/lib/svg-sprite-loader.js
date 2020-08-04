import loadScript from "discourse/lib/load-script";

export default {
  name: "svg-sprite-loader",
  load(spritePath, spriteName) {
    const c = "svg-sprites";
    const $cEl = `#${c}`;
    const $spriteEl = `${$cEl} .${spriteName}`;

    if ($($cEl).length === 0) $("body").append(`<div id="${c}">`);

    if ($($spriteEl).length === 0)
      $($cEl).append(`<div class="${spriteName}">`);

    loadScript(spritePath).then(() => {
      $($spriteEl).html(window.__svg_sprite);
      // we got to clean up here... this is one giant string
      delete window.__svg_sprite;
    });
  }
};

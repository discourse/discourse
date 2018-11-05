import { ajax } from "discourse/lib/ajax";

export default {
  name: "svg-sprite-loader",
  load(spritePath, spriteName) {
    const c = "svg-sprites";
    const $cEl = `#${c}`;
    const $spriteEl = `${$cEl} .${spriteName}`;

    if ($($cEl).length === 0) $("body").append(`<div id="${c}">`);
    if ($($spriteEl).length === 0)
      $($cEl).append(`<div class="${spriteName}">`);

    ajax(spritePath, { type: "GET", dataType: "text" }).then(data => {
      $($spriteEl).html(data);
    });
  }
};

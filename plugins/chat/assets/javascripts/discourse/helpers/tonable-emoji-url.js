import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("tonable-emoji-url", function (emoji, scale) {
  if (!emoji.tonable || scale === 1) {
    return emoji.url;
  }

  return emoji.url.split(".png")[0] + `/${scale}.png`;
});

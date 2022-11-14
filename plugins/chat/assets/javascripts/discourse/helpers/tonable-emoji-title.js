import { registerUnbound } from "discourse-common/lib/helpers";

registerUnbound("tonable-emoji-title", function (emoji, diversity) {
  if (!emoji.tonable || diversity === 1) {
    return `:${emoji.name}:`;
  }

  return `:${emoji.name}:t${diversity}:`;
});

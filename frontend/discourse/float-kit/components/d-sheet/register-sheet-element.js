import { untrack } from "@glimmer/validator";
import { modifier } from "ember-modifier";

export default modifier((element, [register, unregister]) => {
  untrack(() => register(element));

  return () => untrack(() => unregister(element));
});

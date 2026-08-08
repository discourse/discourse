import { modifier } from "ember-modifier";

export default modifier((element, [register, unregister]) => {
  register(element);

  return () => unregister(element);
});

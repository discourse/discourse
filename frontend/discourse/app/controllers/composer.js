import {
  addPopupMenuOption,
  clearPopupMenuOptions,
} from "discourse/lib/composer/custom-popup-menu-options";
import Composer, {
  addComposerSaveErrorCallback,
  clearComposerSaveErrorCallback,
} from "discourse/services/composer";

// TODO add deprecation

export default Composer;

export {
  addComposerSaveErrorCallback,
  addPopupMenuOption,
  clearComposerSaveErrorCallback,
  clearPopupMenuOptions,
};

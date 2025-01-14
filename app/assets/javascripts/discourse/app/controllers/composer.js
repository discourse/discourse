import {
  addPopupMenuOption,
  clearPopupMenuOptions,
} from "discourse/lib/composer/custom-popup-menu-options";
import deprecated from "discourse/lib/deprecated";
import Composer, {
  addComposerSaveErrorCallback,
  clearComposerSaveErrorCallback,
  toggleCheckDraftPopup,
} from "discourse/services/composer";

// TODO add deprecation

export default Composer;

function clearPopupMenuOptionsCallback() {
  deprecated(
    "`clearPopupMenuOptionsCallback` is deprecated without replacement as the cleanup is handled automatically.",
    {
      id: "discourse.composer-controller.clear-popup-menu-options-callback",
      since: "3.2",
      dropFrom: "3.3",
    }
  );

  clearPopupMenuOptions();
}

export {
  addComposerSaveErrorCallback,
  addPopupMenuOption,
  clearComposerSaveErrorCallback,
  clearPopupMenuOptions,
  clearPopupMenuOptionsCallback,
  toggleCheckDraftPopup,
};

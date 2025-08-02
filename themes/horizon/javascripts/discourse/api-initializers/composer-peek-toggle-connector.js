import { apiInitializer } from "discourse/lib/api";
import ComposerPeekModeToggle from "../components/composer-peek-mode-toggle";

export default apiInitializer((api) => {
  api.renderInOutlet("before-composer-toggles", ComposerPeekModeToggle);
});

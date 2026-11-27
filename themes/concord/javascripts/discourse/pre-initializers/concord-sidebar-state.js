import { withPluginApi } from "discourse/lib/plugin-api";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import dmMode from "../lib/dm-mode.js";

// The panels our channel list (or the DM list, when that's showing) stands in
// for. Chat's panel is listed by key so this works whether or not the chat
// plugin is installed.
const REPLACED_PANELS = [MAIN_PANEL, "chat"];

// Core and chat both move the sidebar between the forum and chat panels, on
// route changes and when the chat drawer opens or closes. Rather than chase
// each of those, our panel is shown whenever one of theirs is asked for. Core
// leaves combined mode and the panel switcher off while it does.
export default {
  name: "concord-sidebar-state",
  after: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.registerValueTransformer("sidebar-panel", ({ value }) =>
        REPLACED_PANELS.includes(value) ? dmMode.panel : value
      );
    });
  },
};

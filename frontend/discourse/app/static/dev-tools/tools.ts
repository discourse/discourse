import type { ComponentLike } from "@glint/template";
import BlockDebugButton from "./block-debug/button.gts";
import PluginOutletDebugButton from "./plugin-outlet-debug/button.gjs";
import SafeModeButton from "./safe-mode/button.gjs";
import StyleguideButton from "./styleguide/button.gts";
import UpcomingChangesDebugButton from "./upcoming-changes-debug/button.gjs";
import VerboseLocalizationButton from "./verbose-localization/button.gjs";

interface DevTool {
  id: string;
  component: ComponentLike;
}

/**
 * The tools shipped with Discourse, in the order they appear in the toolbar.
 *
 * Adding a tool is an entry here and a component; the toolbar reads this list
 * rather than naming each button itself. Identifiers match the directory a tool
 * lives in.
 */
export const CORE_TOOLS: readonly DevTool[] = [
  { id: "plugin-outlet-debug", component: PluginOutletDebugButton },
  { id: "block-debug", component: BlockDebugButton },
  { id: "upcoming-changes-debug", component: UpcomingChangesDebugButton },
  { id: "safe-mode", component: SafeModeButton },
  { id: "verbose-localization", component: VerboseLocalizationButton },
  { id: "styleguide", component: StyleguideButton },
];

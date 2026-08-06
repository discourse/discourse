import type { ComponentLike } from "@glint/template";
import BlockDebugButton from "./block-debug/button";
import PluginOutletDebugButton from "./plugin-outlet-debug/button";
import SafeModeButton from "./safe-mode/button";
import UpcomingChangesDebugButton from "./upcoming-changes-debug/button";
import VerboseLocalizationButton from "./verbose-localization/button";

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
];

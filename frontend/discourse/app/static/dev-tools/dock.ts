import { trackedMap } from "@ember/reactive/collections";
import type { ComponentLike } from "@glint/template";
import devToolsState from "discourse/static/dev-tools/state";

const DOCK_TOOL_ID = "dock";
const panels = trackedMap<string, DockPanelRegistration>();

export interface DockPanelRegistration {
  label: string;
  component: ComponentLike;
}

export function registerDockPanel(
  toolId: string,
  registration: DockPanelRegistration
): void {
  panels.set(toolId, registration);
}

export function dockPanels(): Array<
  DockPanelRegistration & { toolId: string }
> {
  return Array.from(panels, ([toolId, registration]) => ({
    toolId,
    ...registration,
  }));
}

export function dockState(): { open: boolean; activeTool: string | undefined } {
  return {
    open:
      (devToolsState.getFlag(DOCK_TOOL_ID, "open") as boolean | undefined) ??
      false,
    activeTool: devToolsState.getFlag(DOCK_TOOL_ID, "activeTool") as
      | string
      | undefined,
  };
}

export function toggleDockTool(toolId: string): void {
  const state = dockState();

  if (state.open && state.activeTool === toolId) {
    closeDock();
  } else {
    activateDockTool(toolId);
  }
}

export function activateDockTool(toolId: string): void {
  devToolsState.setFlag(DOCK_TOOL_ID, "activeTool", toolId);
  devToolsState.setFlag(DOCK_TOOL_ID, "open", true);
}

export function closeDock(): void {
  devToolsState.setFlag(DOCK_TOOL_ID, "open", false);
}

export function clearDockPanels(): void {
  panels.clear();
}

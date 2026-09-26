import { tracked } from "@glimmer/tracking";
import type { LayoutEntry } from "discourse/blocks/types";

class OutletLayouts {
  @tracked names = new Set<string>();

  readonly layouts = new Map<string, { validatedLayout: Promise<LayoutEntry[]> }>();

  set(name: string, value: { validatedLayout: Promise<LayoutEntry[]> }) {
    this.layouts.set(name, value);
    this.names = new Set([...this.names, name]);
  }

  clear() {
    this.layouts.clear();
    this.names = new Set();
  }
}

// Kept apart from the block system, so boot code can ask whether an outlet
// has anything to render without loading it.
export const outletLayouts = new OutletLayouts();

export function _hasLayout(outletName: string): boolean {
  return outletLayouts.names.has(outletName);
}

// Outlet names plugins add, for the container query stylesheet.
class CustomOutletNames {
  @tracked names: string[] = [];

  add(name: string) {
    this.names = [...this.names, name];
  }

  reset() {
    this.names = [];
  }
}

export const customOutletNames = new CustomOutletNames();

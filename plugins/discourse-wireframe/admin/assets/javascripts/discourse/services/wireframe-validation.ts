import Service, { service } from "@ember/service";
import { _getResolvedLayouts } from "discourse/blocks/block-outlet";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";
import type { BlockRegistryEntry } from "discourse/lib/blocks/-internals/types";
import type BlocksService from "discourse/services/blocks";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/entry-key";
import {
  type FriendlyEntryMessage,
  friendlyEntryMessages,
  type FriendlyValidatedEntry,
} from "discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message";
import type WireframeLayoutSignalService from "./wireframe-layout-signal";

/** Flat validation warning shown by the publish drawer. */
export interface ValidationWarning {
  /** Human-readable validation failure. */
  message: string;
  /** Outlet containing the failing entry. */
  outletName: string;
}

/** Navigable validation issue shown by editor chrome. */
export interface ValidationIssue {
  /** Composite key of the failing entry, or `null` when unavailable. */
  blockKey: string | null;
  /** Friendly block name, or `null` when the block cannot be resolved. */
  blockName: string | null;
  /** Author-facing messages derived from the entry's failure details. */
  messages: FriendlyEntryMessage[];
  /** Outlet containing the failing entry. */
  outletName: string;
}

/**
 * Surfaces the editor's validation warnings — the per-entry `__failureReason`
 * stamps the permissive validator leaves behind — as a flat list the chrome and
 * the publish drawer banner render. A read-only peer service: it owns no state,
 * deriving everything from the live resolved layouts on each read.
 *
 * Depends only on the layout signal (to re-evaluate after a structural
 * republish); consumers reach it through the orchestrator's facades.
 */
export default class WireframeValidationService extends Service {
  /** Resolves registered blocks and their metadata. */
  @service declare blocks: BlocksService;
  /** Invalidates warning projections after structural layout changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /**
   * Validation warnings across every outlet the editor is currently
   * drafting. Walks each outlet's resolved layout and harvests the
   * per-entry `__failureReason` stamps the permissive validator leaves
   * behind (paired 1:1 with the layer-level warnings — see
   * `validation/layout.js`'s `markEntrySoftFailure` + `context.warnings`).
   *
   * Reading the stamps rather than the layer record's frozen
   * `validationWarnings` array is what lets the inspector banner clear
   * the moment the author fixes a failing arg: in-place arg writes go
   * through `writeArgs`, which deletes the entry's stamps but doesn't
   * touch the layer array. The two surfaces (per-block ghost chrome,
   * outlet-wide banner) now agree on the live state.
   *
   * Reactivity: reads the layout signal so structural republishes
   * re-evaluate; entry stamp reads (on the trackedObject-wrapped entry)
   * open their own deps so arg-edit stamp clears propagate too.
   * Validation itself is async (`validatedLayout` is a lazy Promise
   * resolved after `BlockOutlet` first reads it); on the very first
   * render after a publish, stamps may not yet be populated and this
   * getter returns an empty list until the next tick.
   *
   * @returns Current validation warnings across drafted outlets.
   */
  get validationWarnings(): ValidationWarning[] {
    // The layout signal covers republishes (validation re-runs against
    // the freshly-published layer). In-place stamp changes propagate via
    // the per-entry `trackedObject` wrap — each `entry.__failureReason`
    // read below opens a per-key dep that fires when `revalidateEntryStamps`
    // rewrites or deletes `entry.__failureReason` on an arg edit.
    void this.wireframeLayoutSignal.version;
    const layoutMap = _getResolvedLayouts();
    const warnings: ValidationWarning[] = [];
    for (const [outletName, record] of layoutMap) {
      if (!record?.layout) {
        continue;
      }
      this.#collectStampedWarnings(record.layout, outletName, warnings);
    }
    return warnings;
  }

  /** Whether any drafted outlet currently contains a validation warning. */
  get hasValidationWarnings(): boolean {
    return this.validationWarnings.length > 0;
  }

  /**
   * The same failing entries as `validationWarnings`, but enriched for a
   * navigable, author-facing issue list: each carries the offending
   * block's key (so a consumer can select + reveal it), its block name,
   * and the friendly per-detail messages `friendlyEntryMessages` derives
   * from the structured `__failureDetails` stamps — rather than the raw
   * developer string `validationWarnings` surfaces.
   *
   * `validationWarnings` is deliberately left untouched (the publish
   * drawer depends on its flat `{outletName, message}` shape); this is a
   * richer parallel projection over the same walk.
   *
   * Reactivity matches `validationWarnings`: the layout signal covers
   * republishes, and reading `__failureReason` / `__failureDetails` on
   * each entry opens the per-key `trackedObject` deps so an arg-edit
   * stamp clear drops the issue live. Note `__failureDetails` is only
   * populated in the permissive session-draft layer; strict-mode layers
   * leave it absent and `friendlyEntryMessages` falls back to the reason.
   *
   * @returns Navigable validation issues across drafted outlets.
   */
  get validationIssues(): ValidationIssue[] {
    void this.wireframeLayoutSignal.version;
    const layoutMap = _getResolvedLayouts();
    // Resolve string block refs to their component, so a failing entry can
    // surface the same friendly display name + arg labels the palette and
    // inspector show. Class refs carry their component directly.
    const componentByName = new Map(
      this.blocks
        .listBlocksWithMetadata()
        .map(({ name, component }) => [name, component])
    );
    const issues: ValidationIssue[] = [];
    for (const [outletName, record] of layoutMap) {
      if (!record?.layout) {
        continue;
      }
      this.#collectStampedIssues(
        record.layout,
        outletName,
        issues,
        componentByName
      );
    }
    return issues;
  }

  /**
   * Recursively walks `entries` and pushes one `{outletName, message}`
   * warning for every entry carrying a `__failureReason` stamp. Reads
   * `__failureReason` rather than the truthy stamp pair (`__failureType`
   * is also set) because the message is what the UI surfaces.
   *
   * @param entries - Layout entries to inspect recursively.
   * @param outletName - Outlet containing the entries.
   * @param warnings - Destination for discovered warnings.
   */
  #collectStampedWarnings(
    entries: FriendlyValidatedEntry[],
    outletName: string,
    warnings: ValidationWarning[]
  ): void {
    for (const entry of entries) {
      if (entry?.__failureReason) {
        warnings.push({ outletName, message: entry.__failureReason });
      }
      if (entry?.children?.length) {
        this.#collectStampedWarnings(entry.children, outletName, warnings);
      }
    }
  }

  /**
   * Recursively walks `entries` and pushes one enriched issue for every
   * entry carrying a `__failureReason` stamp. Reads `__failureReason`
   * first as the guard — that per-key dep is what fires when a stamp
   * clears — then reads `__failureDetails` (via `friendlyEntryMessages`)
   * only inside the branch, so a fresh, never-failed entry opens no
   * detail dep (matching `validationWarnings`).
   *
   * @param entries - Layout entries to inspect recursively.
   * @param outletName - Outlet containing the entries.
   * @param issues - Destination for discovered issues.
   * @param componentByName - Registered block components keyed by name.
   */
  #collectStampedIssues(
    entries: FriendlyValidatedEntry[],
    outletName: string,
    issues: ValidationIssue[],
    componentByName: Map<string, BlockRegistryEntry>
  ): void {
    for (const entry of entries) {
      if (entry?.__failureReason) {
        const component =
          typeof entry.block === "string"
            ? componentByName.get(entry.block)
            : entry.block;
        const metadata = component ? getBlockMetadata(component) : null;
        issues.push({
          outletName,
          blockKey: entryKey(entry),
          // The palette's friendly display name; falls back to the raw
          // string ref for an unregistered block (no resolvable component).
          blockName:
            (component
              ? getBlockDisplayMetadata(component)?.displayName
              : null) ?? (typeof entry.block === "string" ? entry.block : null),
          messages: friendlyEntryMessages(entry, metadata?.args),
        });
      }
      if (entry?.children?.length) {
        this.#collectStampedIssues(
          entry.children,
          outletName,
          issues,
          componentByName
        );
      }
    }
  }
}

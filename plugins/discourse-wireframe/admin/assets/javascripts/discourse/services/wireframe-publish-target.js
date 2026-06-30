// @ts-check
import { trackedObject } from "@ember/reactive/collections";
import Service, { service } from "@ember/service";
import { LAYOUT_SOURCE } from "discourse/blocks/block-outlet";
import PreloadStore from "discourse/lib/preload-store";

/**
 * Owns the editor's theme / publish-target concern: which theme the session
 * publishes to (`activeThemeId`), the per-theme metadata (name / git / stack
 * rank from the boot preload), and the derived publish plan (`publishTargets` /
 * `activeThemeTarget` / `outletOwner`). A peer service in the editor's acyclic
 * graph — injects the read-only layer query (`blocks`), the site (theme list
 * fallback), and the mutation/undo engine (the edited-outlet set for the
 * publish plan); it never reaches back into the orchestrator. The
 * session service drives `activeThemeId` downward (set on enter, repointed to a
 * companion after the async lookup, cleared on exit).
 */
export default class WireframePublishTargetService extends Service {
  @service blocks;
  @service site;
  @service wireframeMutationEngine;

  #state = trackedObject({ activeThemeId: null });

  /**
   * The theme this session publishes to — set on enter (an explicit
   * `enter({ themeId })` or the default target) and repointed to a publishable
   * companion when the bound theme can't be published to directly. Null while
   * no session is active.
   *
   * @returns {number|null}
   */
  get activeThemeId() {
    return this.#state.activeThemeId;
  }

  /**
   * Whether the editor is bound to a core "system" theme (Foundation, Horizon),
   * which have negative ids. Such themes can't be published to directly — the
   * editor offers an installable companion component instead — so the toolbar
   * uses this to disable the direct Publish action.
   *
   * @returns {boolean}
   */
  get activeThemeIsSystem() {
    return this.activeThemeId != null && this.activeThemeId < 0;
  }

  /**
   * The theme this session would publish to before anything is edited — the
   * theme the editor was entered against (or the default target). Used by the
   * toolbar target indicator to name the destination up front, with the same
   * `publishable` shape as a `publishTargets` group so the indicator can render
   * either uniformly. Null when no target can be resolved.
   *
   * @returns {{themeId: number, themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean}|null}
   */
  get activeThemeTarget() {
    const themeId = this.activeThemeId ?? this.defaultThemeId;
    if (themeId == null) {
      return null;
    }
    const themeMeta = this.#themeMeta(themeId);
    const isSystem = themeId < 0;
    const isGit = themeMeta?.is_git ?? false;
    return {
      themeId,
      themeName: themeMeta?.name ?? null,
      isGit,
      isSystem,
      publishable: !isGit && !isSystem,
    };
  }

  /**
   * The theme an outlet publishes to when nothing yet owns it (a pure in-code
   * default with no live field). Exposed so the live-layout peer can resolve a
   * fallback publish target without reaching into the private resolver.
   *
   * @returns {number|null}
   */
  get defaultThemeId() {
    return this.#defaultThemeId();
  }

  /**
   * The edited outlets grouped by the theme that owns them — the publish plan.
   * Each group names its target theme and whether that theme can be published to
   * directly (a local, non-Git theme) or needs the companion/duplicate/export
   * path instead (a Git-managed or core "system" theme). Drives the publish
   * review surface and the toolbar target indicator.
   *
   * Reactive: derives from the engine's `editedOutletNames()` (which reads the
   * tracked edit bookkeeping) and `outletOwner` (which reads the tracked layer
   * store), so a template re-renders as edits and their owners change.
   *
   * @returns {Array<{themeId: (number|null), themeName: (string|null), isGit: boolean, isSystem: boolean, publishable: boolean, outlets: Array<string>}>}
   */
  get publishTargets() {
    const groups = new Map();
    for (const outletName of this.wireframeMutationEngine.editedOutletNames()) {
      const owner = this.outletOwner(outletName);
      let group = groups.get(owner.themeId);
      if (!group) {
        const isSystem = owner.themeId != null && owner.themeId < 0;
        group = {
          themeId: owner.themeId,
          themeName: owner.themeName,
          isGit: owner.isGit,
          isSystem,
          publishable: !owner.isGit && !isSystem,
          outlets: [],
        };
        groups.set(owner.themeId, group);
      }
      group.outlets.push(outletName);
    }
    return [...groups.values()];
  }

  /**
   * Hard-navigates the editor onto a different theme by reloading the current
   * page with `?wf_theme=<id>`. A full document load is required (not an SPA
   * transition) so the boot preload re-seeds the new theme's block layouts and
   * per-theme metadata; the entry pill then auto-enters bound to it. Used after
   * duplicate / create-customization-component so the new owner takes effect and
   * Publish enables. Isolated here as a thin, stubbable seam.
   *
   * @param {number} themeId
   */
  navigateToEditTheme(themeId) {
    const url = new URL(window.location.href);
    url.searchParams.set("wf_theme", themeId);
    window.location.assign(url.toString());
  }

  /**
   * The theme that owns an outlet (where Publish writes its live field) plus
   * the metadata needed to badge and gate it. For a published outlet the owner
   * is the theme that holds the field (the most-derived theme, resolved by the
   * core layer resolver); for a default/locked outlet nothing owns it yet, so
   * the target is this session's `activeThemeId` — the theme the editor was
   * entered against (an explicit `enter({ themeId })`) or, for the pill, the
   * current theme. `themeName` and `isGit` come from the per-theme metadata
   * preload.
   *
   * @param {string} outletName
   * @returns {{themeId: (number|null), themeName: (string|null), isGit: boolean, stackIndex: (number|undefined), layer: string}}
   */
  outletOwner(outletName) {
    const meta = this.blocks.resolvedLayoutMeta(outletName, {
      ignoreSessionDraft: true,
    });
    const themeId =
      meta?.source === LAYOUT_SOURCE.THEME
        ? Number(meta.sourceId)
        : (this.activeThemeId ?? this.defaultThemeId);
    const themeMeta = this.#themeMeta(themeId);
    return {
      themeId,
      themeName: themeMeta?.name ?? null,
      isGit: themeMeta?.is_git ?? false,
      stackIndex:
        meta?.source === LAYOUT_SOURCE.THEME
          ? meta.themeStackIndex
          : themeMeta?.stack_index,
      layer: meta?.source ?? null,
    };
  }

  /**
   * Clears the active theme (session teardown). The derived getters then fall
   * back to `defaultThemeId` until the next session sets a theme.
   */
  reset() {
    this.#state.activeThemeId = null;
  }

  /**
   * Binds the session to a theme. A null / undefined id falls back to the
   * default target (the parent of the active stack), mirroring how an
   * `enter()` without an explicit theme resolves.
   *
   * @param {number|null} [themeId]
   */
  setActiveTheme(themeId) {
    this.#state.activeThemeId = themeId ?? this.defaultThemeId;
  }

  /**
   * Picks a default theme id for editor sessions that didn't supply one (the
   * pill entry, vs. an explicit `enter({ themeId })`). This is the theme the
   * page actually renders against — the parent of the active stack, which is
   * `stack_index 0` in `Theme.transform_ids` — so edits to an outlet nothing
   * owns yet save back to the current theme.
   *
   * Derived from the `themeBlockLayoutMeta` preload, which carries each stack
   * theme's `stack_index` and includes seeded default themes (negative ids like
   * Foundation `-1`). NOT from `activatedThemes`: that is an unordered
   * `{ id: name }` map, and a numeric-key lookup would both lose the stack order
   * and skip the negative-id parent.
   *
   * Falls back to the user-selectable themes list when the meta preload is
   * unavailable or empty. Returns null when no themes are available, in which
   * case the Save / Publish control stays disabled.
   *
   * @returns {number|null}
   */
  #defaultThemeId() {
    const meta = PreloadStore.get("themeBlockLayoutMeta");
    if (meta && typeof meta === "object") {
      let parentId = null;
      let minRank = Infinity;
      for (const [id, info] of Object.entries(meta)) {
        const rank = info?.stack_index ?? Infinity;
        if (rank < minRank) {
          minRank = rank;
          parentId = Number(id);
        }
      }
      if (parentId != null) {
        return parentId;
      }
    }
    const themes = this.site?.user_themes ?? [];
    return (
      themes.find((t) => t.default)?.theme_id ?? themes[0]?.theme_id ?? null
    );
  }

  /**
   * Per-theme metadata from the boot preload (display name, git status, stack
   * rank), keyed by theme id. The preload is JSON, so its keys are strings;
   * coerce the lookup id to a string. Returns null when the theme is absent.
   *
   * @param {number|string|null} themeId
   * @returns {?{name: string, component: boolean, is_git: boolean, stack_index: number}}
   */
  #themeMeta(themeId) {
    if (themeId == null) {
      return null;
    }
    const meta = PreloadStore.get("themeBlockLayoutMeta");
    if (!meta || typeof meta !== "object") {
      return null;
    }
    return meta[String(themeId)] ?? null;
  }
}

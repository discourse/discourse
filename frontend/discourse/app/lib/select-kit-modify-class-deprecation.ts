import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import type { CustomizationSource } from "discourse/lib/customization-source";
import deprecated from "discourse/lib/deprecated";
import {
  type default as identifySource,
  noticeSourceFor,
} from "discourse/lib/source-identifier";
import compatModules from "discourse/select-kit/compat-modules";

/** The deprecation id; the workflow throws on it in development and notifies admins in production. */
export const SELECT_KIT_MODIFY_CLASS_DEPRECATION_ID =
  "discourse.select-kit-rollout.modify-class";

/**
 * Select-kit modules, by path relative to `select-kit/components` (`"category-drop"`,
 * `"select-kit/select-kit-row"`), whose core call sites render the new select controls when
 * `enable_new_select_controls` is on. A family adds its modules here when its converted call
 * sites merge; a patch on any other module still reaches every call site, so it isn't reported.
 */
export const MIGRATED_SELECT_KIT_MODULES = new Set<string>([
  "category-chooser",
  "category-drop",
  "category-drop/category-drop-header",
  "category-drop-more-collection",
  "category-row",
  "category-selector",
  "multiple-categories-selector",
  "search-advanced-category-chooser",
  "selected-choice-category",

  "mini-tag-chooser",
  "mini-tag-chooser/selected-collection",
  "tag-chooser",
  "tag-chooser-row",
  "tag-drop",
  "tag-drop/tag-drop-header",
  "tag-dropdown",
  "tag-group-chooser",
  "tag-row",
  "tags-intersection-chooser",

  "email-group-user-chooser",
  "email-group-user-chooser-filter",
  "email-group-user-chooser-row",
  "group-chooser",
  "user-chooser",
  "user-chooser/user-row",
]);

const selectKitModules = compatModules as Record<
  string,
  { default?: unknown } | undefined
>;

let legacyRenderNotices = new WeakMap<object, Set<string>>();

/** Clears legacy render notice deduplication between tests. */
export function resetSelectKitLegacyRenderNotices(): void {
  legacyRenderNotices = new WeakMap();
}

/**
 * Reports a migrated family's legacy render after rendering, once per class and source.
 * @param source - Captured synchronously in init, before deferral loses the caller's stack.
 */
export function deprecateSelectKitLegacyRender(
  instance: object,
  source: ReturnType<typeof identifySource>
): void {
  if (MIGRATED_SELECT_KIT_MODULES.size === 0) {
    return;
  }

  const isMigrated = [...MIGRATED_SELECT_KIT_MODULES].some((path) => {
    const klass = selectKitModules[`./components/${path}`]?.default;
    return typeof klass === "function" && instance instanceof klass;
  });
  if (!isMigrated) {
    return;
  }

  const siteSettings: unknown = getOwner(instance)?.lookup(
    "service:site-settings"
  );
  if (
    !siteSettings ||
    typeof siteSettings !== "object" ||
    !("enable_new_select_controls" in siteSettings) ||
    !siteSettings.enable_new_select_controls
  ) {
    return;
  }

  const sourceKey = source
    ? JSON.stringify([source.type, "id" in source ? source.id : source.name])
    : "core/unknown";
  let reportedSources = legacyRenderNotices.get(instance.constructor);
  if (!reportedSources) {
    reportedSources = new Set();
    legacyRenderNotices.set(instance.constructor, reportedSources);
  }
  if (reportedSources.has(sourceKey)) {
    return;
  }
  reportedSources.add(sourceKey);

  schedule("afterRender", () => {
    deprecated(
      "Core renders the new select controls for this family while `enable_new_select_controls` is on, so this select-kit render is a third-party use that will stop working when select-kit is removed. Move to the new select controls.",
      {
        id: "discourse.select-kit-rollout.legacy-render",
        since: "2026.10.0",
        source,
      }
    );
  });
}

/**
 * Deprecates an `api.modifyClass` or `api.modifyClassStatic` patch on a migrated select-kit
 * module while the new select controls are on, because core no longer renders that class there.
 * Called after the patch is applied, so the patch still reaches third-party call sites even when
 * the deprecation throws.
 *
 * Only an exact match counts: a subclass defined elsewhere keeps rendering select-kit, so a patch
 * on it keeps working.
 *
 * @param klass - The resolved factory that was patched.
 * @param resolverName - The name the patch targeted, for the message.
 * @param apiName - `modifyClass` or `modifyClassStatic`, for the message.
 * @param source - The plugin, theme, or core code that made the patch.
 * @param lookup - Looks up a container entry. Only called once the target is known to be
 *   migrated, since a lookup instantiates and caches the entry, which would stop it being patched.
 */
export function deprecateSelectKitModifyClass(
  klass: { class: unknown },
  resolverName: string,
  apiName: string,
  source: CustomizationSource,
  lookup: (path: string) => unknown
): void {
  if (MIGRATED_SELECT_KIT_MODULES.size === 0) {
    return;
  }

  const isMigrated = [...MIGRATED_SELECT_KIT_MODULES].some(
    (path) => selectKitModules[`./components/${path}`]?.default === klass.class
  );
  if (!isMigrated) {
    return;
  }

  const siteSettings = lookup("service:site-settings") as
    | { enable_new_select_controls?: boolean }
    | undefined;
  if (!siteSettings?.enable_new_select_controls) {
    return;
  }

  deprecated(
    `\`api.${apiName}\` on \`${resolverName}\` no longer affects core's dropdowns while \`enable_new_select_controls\` is on, because they render the new select controls instead of this select-kit class. Customize the new controls through their supported APIs instead.`,
    {
      id: SELECT_KIT_MODIFY_CLASS_DEPRECATION_ID,
      since: "2026.10.0",
      source: noticeSourceFor(source),
    }
  );
}

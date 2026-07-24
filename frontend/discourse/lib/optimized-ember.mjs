import { ResolverLoader } from "@embroider/core";
import { resolver, templateTag } from "@embroider/vite";
import { id, importerId, include, or } from "@rolldown/pluginutils";
import { viteAliasPlugin } from "rolldown/experimental";

function toSpecifier(s) {
  return s.replace(/(?:\/index)?\.js$/, "");
}

/*
 * Embroider's resolver handles a number of static module aliases. For example - the
 * fake packages like `@ember/component`. We can fetch that list from the resolver upfront
 * and pipe it into the highly-optimized viteAliasPlugin. This means that they will be
 * resolved entirely on the rust side - no round-trip to node.
 */
function staticEmbroiderAliases() {
  const { renameModules = {} } = new ResolverLoader(process.cwd()).resolver
    .options;
  const entries = Object.entries(renameModules).map(([find, replacement]) => ({
    find: toSpecifier(find),
    replacement: toSpecifier(replacement),
  }));
  return viteAliasPlugin({ entries });
}

/*
 * By default, the embroider resolver runs for every resolveId call.
 * We have moved its static lookup rules into the highly-optimised viteAliasPlugin,
 * and we have no need for its hbs-related synthetic modules or app-tree merging.
 * Therefore we can filter the plugin so that it's only called for `@embroider/*`
 * virtual modules, and for any imports *from* a -embroider- module.
 */
function filteredEmberResolver() {
  const plugin = resolver();
  plugin.resolveId = {
    filter: [
      include(
        or(
          // @embroider/* could be dynamic modules
          id(/^@embroider\//),
          // /-embroider-* need access to the app-tree-merge result so that addon-contributed app-tree-merge modules are available in compatModules
          importerId(/\/-embroider-/)
        )
      ),
    ],
    handler: plugin.resolveId,
  };
  return plugin;
}

/**
 * Drop-in replacement for `@embroider/vite`'s `ember()`.
 * Skips the two vite-specific plugins, since we're using rolldown.
 * Uses an optimized strategy for the resolver.
 */
export default function optimizedEmber() {
  return [staticEmbroiderAliases(), templateTag(), filteredEmberResolver()];
}

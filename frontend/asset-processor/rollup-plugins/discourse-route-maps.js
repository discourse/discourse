import {
  buildRouteTree,
  deriveRoutes,
  parseRouteMap,
  routeTablesFor,
} from "../route-map-parser";

// Core's own maps, added to the tree by `Plugin::JsManager` so `resource` mounts can resolve.
// They generate routes from site settings in loops, so they are the only maps read leniently.
const CORE_MAPS = ["__core__/app-route-map.js", "__core__/admin-route-map.js"];

const ROUTE_MAP_REGEX = /route-map\.js$/;

// Fills `tables` before any module loads, because the entrypoint's own source depends on it.
export default function discourseRouteMaps({
  modules,
  label,
  tables,
  staticModules,
}) {
  return {
    name: "discourse-route-maps",
    buildStart() {
      // Route maps are only read for plugins that opt into `staticModules`. Everything else
      // imports its routes eagerly and needs no bundles, so a map this cannot read is none of
      // its business — `discourse-docs` builds its path from a site setting, and would
      // otherwise fail to compile over a table nothing would read.
      if (!staticModules) {
        return;
      }

      // Only `Plugin::JsManager` supplies core's maps, and without them a `resource` mount
      // cannot be resolved. Themes therefore derive no bundles, which is what they do today.
      if (!CORE_MAPS.some((filename) => modules[filename])) {
        return;
      }

      const filenames = Object.keys(modules).filter((filename) =>
        ROUTE_MAP_REGEX.test(filename)
      );

      // Core first, so a plugin extending a core route merges into it rather than creating it.
      filenames.sort(
        (a, b) =>
          CORE_MAPS.indexOf(b) - CORE_MAPS.indexOf(a) || a.localeCompare(b)
      );

      const maps = filenames.map((filename) => {
        const source = modules[filename];
        const core = CORE_MAPS.includes(filename);

        return {
          filename,
          core,
          ...parseRouteMap(this.parse(source), {
            filename,
            source,
            label,
            lenient: core,
          }),
        };
      });

      const { root, unmounted } = buildRouteTree(maps);

      for (const map of unmounted) {
        throw new Error(
          `[${label}] ${map.filename} mounts on "${map.resource}", which is not a route.`
        );
      }

      Object.assign(tables, routeTablesFor(deriveRoutes(root)));
    },
  };
}

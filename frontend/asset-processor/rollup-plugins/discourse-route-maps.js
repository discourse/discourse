import {
  buildRouteTree,
  deriveRoutes,
  parseRouteMap,
  routeTablesFor,
} from "../route-map-parser";

// Added to the tree by `Plugin::JsManager`. These build routes in loops, so they are read
// leniently and a plugin's `resource` can mount on them.
const CORE_MAPS = ["__core__/app-route-map.js", "__core__/admin-route-map.js"];

const ROUTE_MAP_REGEX = /route-map\.js$/;

// Fills `tables` before any module loads, because the entrypoint's source is generated from it.
export default function discourseRouteMaps({
  modules,
  label,
  tables,
  staticModules,
}) {
  return {
    name: "discourse-route-maps",
    buildStart() {
      if (!staticModules) {
        return;
      }

      // Themes get no core maps, so they cannot resolve a `resource` mount and derive no bundles.
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

import {
  buildRouteTree,
  bundleByRouteFor,
  deriveRoutes,
  parseRouteMap,
} from "../route-map-parser";

// Added to the tree by `Plugin::JsManager`. These build routes in loops, so they are read
// leniently and a plugin's `resource` can mount on them.
const CORE_MAP_REGEX = /^__core__\//;

const ROUTE_MAP_REGEX = /route-map\.js$/;

function isCoreMap(filename) {
  return CORE_MAP_REGEX.test(filename);
}

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

      const filenames = Object.keys(modules).filter((filename) =>
        ROUTE_MAP_REGEX.test(filename)
      );

      // Themes get no core maps, so they cannot resolve a `resource` mount and derive no bundles.
      if (!filenames.some(isCoreMap)) {
        return;
      }

      // Core first, so a plugin extending a core route merges into it rather than creating it.
      filenames.sort(
        (a, b) =>
          Number(!isCoreMap(a)) - Number(!isCoreMap(b)) || a.localeCompare(b)
      );

      const maps = filenames.map((filename) => {
        const source = modules[filename];
        const core = isCoreMap(filename);

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

      const [unmountable] = unmounted;

      if (unmountable) {
        throw new Error(
          `[${label}] ${unmountable.filename} mounts on "${unmountable.resource}", which is not a route.`
        );
      }

      const derived = deriveRoutes(root);

      Object.assign(tables, {
        derived,
        bundleByRoute: bundleByRouteFor(derived),
      });
    },
  };
}

import { relative } from "path";

// Writes the static import graph so `script/boot-size/why.mjs` can explain
// why a module is in the boot closure.
export default function moduleGraphPlugin({ enabled }) {
  return {
    name: "module-graph",
    generateBundle() {
      if (!enabled) {
        return;
      }

      const rel = (id) => {
        const nm = id.lastIndexOf("node_modules/");
        return nm >= 0 ? id.slice(nm) : relative(process.cwd(), id);
      };

      const graph = {};
      for (const id of this.getModuleIds()) {
        const info = this.getModuleInfo(id);
        if (!info) {
          continue;
        }
        graph[rel(id)] = {
          imports: info.importedIds.map(rel),
          dynamicImports: info.dynamicallyImportedIds.map(rel),
        };
      }

      this.emitFile({
        type: "asset",
        fileName: "manifest/module-graph.json",
        source: JSON.stringify(graph),
      });
    },
  };
}

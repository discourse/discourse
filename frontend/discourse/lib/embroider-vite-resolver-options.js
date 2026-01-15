import { buildResolverOptions } from "@embroider/core/module-resolver-options";
import fs from "node:fs";
import path from "node:path";

export default function writeResolverConfig(config, extra) {
  const embroiderResolverOptions = {
    ...buildResolverOptions(config),
    ...extra,
  };

  const resolverPath = path.resolve("./node_modules/.embroider/resolver.json");
  const embroiderDir = path.resolve("./node_modules/.embroider");

  if (fs.existsSync(embroiderDir)) {
    fs.rmSync(embroiderDir, {
      recursive: true,
      force: true,
    });
  }
  fs.mkdirSync(path.dirname(resolverPath), { recursive: true });
  fs.writeFileSync(
    resolverPath,
    JSON.stringify(embroiderResolverOptions, null, 2)
  );
}

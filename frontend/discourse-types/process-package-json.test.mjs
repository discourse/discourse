import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import processPackageJson from "./process-package-json.js";

function fixturePackage(t, packageJson, files) {
  const dir = mkdtempSync(join(tmpdir(), "process-package-json-"));
  t.after(() => rmSync(dir, { recursive: true }));

  for (const file of files) {
    mkdirSync(join(dir, file, ".."), { recursive: true });
    writeFileSync(join(dir, file), "export {};\n");
  }

  return { packageJson, packagePath: dir };
}

test("reads `typings` through `typesVersions`, like TypeScript", (t) => {
  const { packageJson, packagePath } = fixturePackage(
    t,
    {
      typings: "./gizmo.d.ts",
      typesVersions: { ">=3.1": { "*": ["ts3.1-typings/*"] } },
    },
    ["gizmo.d.ts", "ts3.1-typings/gizmo.d.ts"]
  );

  assert.deepEqual(
    [...processPackageJson(packageJson, packagePath)],
    [["ts3.1-typings/gizmo", { remove: "ts3.1-typings/gizmo", add: undefined }]]
  );
});

test("reads `types` as given without `typesVersions`", (t) => {
  const { packageJson, packagePath } = fixturePackage(
    t,
    { types: "./gizmo.d.ts" },
    ["gizmo.d.ts"]
  );

  assert.deepEqual(
    [...processPackageJson(packageJson, packagePath)],
    [["gizmo", { remove: "gizmo", add: undefined }]]
  );
});

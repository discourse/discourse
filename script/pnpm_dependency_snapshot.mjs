// Converts `pnpm sbom --lockfile-only --sbom-format cyclonedx` output into a
// GitHub dependency submission snapshot for `pnpm-lock.yaml`.

import { readFileSync } from "node:fs";

const LOCKFILE = "pnpm-lock.yaml";

const sbom = JSON.parse(readFileSync(process.argv[2], "utf8"));
const minPackages = Number(process.env.MIN_PACKAGES || 1);

const isRegistryPackage = (component) =>
  component.externalReferences?.some((ref) => ref.type === "distribution");

const isDevelopment = (component) =>
  component.properties?.some(
    (prop) =>
      prop.name === "cdx:npm:package:development" && prop.value === "true"
  );

const packages = sbom.components.filter(isRegistryPackage);
const packageRefs = new Set(packages.map((c) => c["bom-ref"]));
const edges = new Map(
  sbom.dependencies.map((d) => [d.ref, d.dependsOn ?? []])
);

const projects = [
  sbom.metadata.component,
  ...sbom.components.filter((c) => !isRegistryPackage(c)),
];
const direct = new Set(projects.flatMap((p) => edges.get(p["bom-ref"]) ?? []));

if (packages.length < minPackages) {
  console.error(
    `Found ${packages.length} packages in ${LOCKFILE}, expected at least ${minPackages}.`
  );
  process.exit(1);
}

const resolved = Object.fromEntries(
  packages.map((c) => [
    c.purl,
    {
      package_url: c.purl,
      relationship: direct.has(c["bom-ref"]) ? "direct" : "indirect",
      scope: isDevelopment(c) ? "development" : "runtime",
      dependencies: (edges.get(c["bom-ref"]) ?? []).filter((ref) =>
        packageRefs.has(ref)
      ),
    },
  ])
);

const pnpm = sbom.metadata.tools?.components?.find((t) => t.name === "pnpm");

const snapshot = {
  version: 0,
  sha: process.env.GITHUB_SHA,
  ref: process.env.GITHUB_REF,
  job: {
    correlator: `${process.env.GITHUB_WORKFLOW}_${process.env.GITHUB_JOB}`,
    id: process.env.GITHUB_RUN_ID,
  },
  detector: {
    name: "pnpm-sbom",
    version: pnpm?.version ?? "unknown",
    url: "https://pnpm.io/cli/sbom",
  },
  scanned: new Date().toISOString(),
  manifests: {
    [LOCKFILE]: {
      name: LOCKFILE,
      file: { source_location: LOCKFILE },
      resolved,
    },
  },
};

const directCount = packages.filter((c) => direct.has(c["bom-ref"])).length;
console.error(
  `${packages.length} packages (${directCount} direct) from ${LOCKFILE}`
);
process.stdout.write(JSON.stringify(snapshot));

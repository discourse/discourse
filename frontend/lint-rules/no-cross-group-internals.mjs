import { posix as path } from "node:path";

const INTERNALS_SEGMENT = "-internals";

function isWithin(candidate, directory) {
  return candidate === directory || candidate.startsWith(`${directory}/`);
}

function normalizedFilename(context) {
  return path.normalize(context.filename.replaceAll("\\", "/"));
}

function moduleIdFor(filename) {
  const segments = filename.split("/");
  const appIndex = segments.lastIndexOf("app");

  if (appIndex === -1 || appIndex === segments.length - 1) {
    return;
  }

  return ["discourse", ...segments.slice(appIndex + 1)].join("/");
}

function mayImportInternals(filename, specifier) {
  const specifierSegments = specifier.split("/");

  // Locate the internals segment on the NORMALIZED target, never on the raw
  // specifier: `./-internals/../../other-group/-internals/x` names this
  // group's internals as a prefix while resolving into another group's.
  if (specifierSegments[0] === "." || specifierSegments[0] === "..") {
    const importerPath = path.resolve(filename);
    const resolved = path.resolve(path.dirname(importerPath), specifier);
    const segments = resolved.split("/");
    const internalsIndex = segments.indexOf(INTERNALS_SEGMENT);

    if (internalsIndex === -1) {
      return true;
    }

    const groupDirectory = segments.slice(0, internalsIndex).join("/");

    if (!groupDirectory.split("/").includes("ui-kit")) {
      return true;
    }

    return isWithin(importerPath, groupDirectory);
  }

  const segments = path.normalize(specifier).split("/");
  const internalsIndex = segments.indexOf(INTERNALS_SEGMENT);

  if (internalsIndex === -1) {
    return true;
  }

  const groupId = segments.slice(0, internalsIndex).join("/");

  if (!groupId.split("/").includes("ui-kit")) {
    return true;
  }

  const importerModuleId = moduleIdFor(filename);

  return Boolean(importerModuleId) && isWithin(importerModuleId, groupId);
}

export default {
  meta: {
    type: "problem",
    messages: {
      crossGroupInternals:
        "Do not import another group's -internals modules; use its public component.",
    },
    schema: [],
  },
  create(context) {
    const filename = normalizedFilename(context);

    if (filename.split("/").includes("tests")) {
      return {};
    }

    function checkSource(node) {
      const specifier = node.source?.value;

      if (typeof specifier !== "string") {
        return;
      }

      // A target can only land inside an internals directory by naming the
      // segment, so a specifier without it needs no resolution at all.
      if (
        !specifier.split("/").includes(INTERNALS_SEGMENT) ||
        mayImportInternals(filename, specifier)
      ) {
        return;
      }

      context.report({
        node: node.source,
        messageId: "crossGroupInternals",
      });
    }

    return {
      ExportAllDeclaration: checkSource,
      ExportNamedDeclaration: checkSource,
      ImportDeclaration: checkSource,
      ImportExpression: checkSource,
    };
  },
};

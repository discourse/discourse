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

function mayImportInternals(filename, specifier, internalsIndex) {
  const specifierSegments = specifier.split("/");

  if (specifierSegments[0] === "." || specifierSegments[0] === "..") {
    const importerPath = path.resolve(filename);
    const groupDirectory = path.resolve(
      path.dirname(importerPath),
      specifierSegments.slice(0, internalsIndex).join("/")
    );

    if (!groupDirectory.split("/").includes("ui-kit")) {
      return true;
    }

    return isWithin(importerPath, groupDirectory);
  }

  const groupId = specifierSegments.slice(0, internalsIndex).join("/");
  const importerModuleId = moduleIdFor(filename);

  if (!groupId.split("/").includes("ui-kit")) {
    return true;
  }

  return importerModuleId && isWithin(importerModuleId, groupId);
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

      const internalsIndex = specifier.split("/").indexOf(INTERNALS_SEGMENT);

      if (
        internalsIndex === -1 ||
        mayImportInternals(filename, specifier, internalsIndex)
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
    };
  },
};

import { Preprocessor } from "content-tag";
import nodeFs from "fs";

const VIRTUAL_PREFIX = "\0discourse-source:";
const MODES = new Set(["file", "template"]);
const preprocessor = new Preprocessor();

/*
 * Importing `<specifier>?source=file` resolves to that module's raw, untranspiled
 * source as a string. `?source=template` narrows it to the contents of the module's
 * single `<template>`. The specifier resolves like a normal import.
 *
 * For example, a documentation page can render a component and display its source
 * without the two drifting apart.
 */
export default function discourseSourceImports({ fs = nodeFs.promises } = {}) {
  return {
    name: "discourse-source-imports",

    resolveId: {
      // The value is deliberately left open so a bad one still reaches the error
      // below rather than being filtered out into an unresolved import.
      filter: { id: /[?&]source(=|&|$)/ },
      async handler(source, importer) {
        const queryStart = source.indexOf("?");

        if (queryStart === -1) {
          return null;
        }

        const query = new URLSearchParams(source.slice(queryStart + 1));
        const modes = query.getAll("source");

        if (modes.length === 0) {
          return null;
        }

        if (modes.length > 1 || !MODES.has(modes[0])) {
          this.error(
            `Source imports require a single ?source= value of "file" or "template".`
          );
        }

        // Anything else in the query is a typo or meant for a loader that will
        // never see it, since this plugin consumes the whole specifier.
        const unknown = [...query.keys()].filter((key) => key !== "source");

        if (unknown.length > 0) {
          this.error(
            `Source imports do not support the "${unknown[0]}" query parameter.`
          );
        }

        const sourcePath = source.slice(0, queryStart);
        const resolved = await this.resolve(sourcePath, importer, {
          skipSelf: true,
        });

        if (!resolved || resolved.external) {
          this.error(`Cannot import source from "${sourcePath}".`);
        }

        // The mode goes last so the id cannot end in the source file's extension.
        // Template transforms match on how an id ends and ignore the \0 marker, so
        // an id ending in .hbs or .gjs gets compiled as a template and the string
        // this plugin produced is overwritten.
        return `${VIRTUAL_PREFIX}${resolved.id}:${modes[0]}`;
      },
    },

    load: {
      filter: { id: /^\0discourse-source:/ },
      async handler(id) {
        const separator = id.lastIndexOf(":");
        const mode = id.slice(separator + 1);
        const sourceId = id.slice(VIRTUAL_PREFIX.length, separator);

        // The virtual id never changes, so without this a watch-mode edit to the
        // source file would not invalidate this module. Inert outside watch mode.
        this.addWatchFile(sourceId);

        const source = await fs.readFile(sourceId, "utf8");
        let contents;

        if (mode === "template") {
          const templates = preprocessor.parse(source, { filename: sourceId });

          if (templates.length !== 1) {
            this.error(
              `Template source imports require exactly one template in "${sourceId}".`
            );
          }

          contents = templates[0].contents;
        } else {
          contents = source;
        }

        return `export default ${JSON.stringify(dedent(contents))};`;
      },
    },
  };
}

function dedent(source) {
  const lines = source
    .replace(/^\r?\n/, "")
    .replace(/\r?\n\s*$/, "")
    .split(/\r?\n/);
  const contentLines = lines.filter((line) => line.trim());
  const indentation = contentLines.length
    ? Math.min(...contentLines.map((line) => line.match(/^\s*/)[0].length))
    : 0;

  return lines.map((line) => line.slice(indentation)).join("\n");
}

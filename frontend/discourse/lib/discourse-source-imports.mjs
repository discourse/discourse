const VIRTUAL_PREFIX = "\0discourse-source:";
const MODES = new Set(["file", "template"]);

/*
 * Importing `<specifier>?source=file` resolves to that module's raw, untranspiled
 * source as a string. `?source=template` narrows it to the contents of the module's
 * single `<template>`. The specifier resolves like a normal import.
 *
 * For example, a documentation page can render a component and display its source
 * without the two drifting apart.
 *
 * `readSource(id)` returns the raw text for a resolved id, or undefined when the id
 * is outside the bundle. It is injected because the pipelines differ: the asset
 * processor bundles from an in-memory map, while core reads from disk.
 */
export default function discourseSourceImports({ readSource, preprocessor }) {
  return {
    name: "discourse-source-imports",

    resolveId: {
      // Deliberately broader than the `source` key: URLSearchParams decodes
      // percent-escapes, so a tighter regex would let `?%73ource=file` slip past the
      // filter and skip the error the handler would otherwise raise.
      filter: { id: /\?/ },
      async handler(source, importer) {
        const queryStart = source.indexOf("?");
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

        if (
          !resolved ||
          resolved.external ||
          readSource(resolved.id) === undefined
        ) {
          this.error(`Cannot import source from "${sourcePath}".`);
        }

        return `${VIRTUAL_PREFIX}${modes[0]}:${resolved.id}`;
      },
    },

    load: {
      filter: { id: /^\0discourse-source:/ },
      handler(id) {
        const separator = id.indexOf(":", VIRTUAL_PREFIX.length);
        const mode = id.slice(VIRTUAL_PREFIX.length, separator);
        const sourceId = id.slice(separator + 1);
        const source = readSource(sourceId);

        // The virtual id never changes, so without this a watch-mode edit to the
        // source file would not invalidate this module. Inert outside watch mode.
        this.addWatchFile(sourceId);

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

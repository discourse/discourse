import { Preprocessor } from "../content-tag";

const QUERIES = new Map([
  ["source", "file"],
  ["template-source", "template"],
]);
const QUERY_NAMES = [...QUERIES.keys()].map((query) => `?${query}`);
const SUPPORTED_EXTENSIONS = [".js", ".ts", ".gjs", ".gts"];
const VIRTUAL_PREFIX = "\0discourse-source:";

const preprocessor = new Preprocessor();

// `?source=true` is a plausible typo for `?source`. Recognize it so it fails
// with the flag error rather than falling through to an unresolved import.
function hasQueryValue(flag) {
  const valueStart = flag.indexOf("=");

  return valueStart !== -1 && QUERIES.has(flag.slice(0, valueStart));
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

export default function discourseSourceImports({ basePath, modules }) {
  return {
    name: "discourse-source-imports",

    async resolveId(source, importer) {
      const queryStart = source.indexOf("?");

      if (queryStart === -1) {
        return null;
      }

      const sourcePath = source.slice(0, queryStart);
      const queryFlags = source.slice(queryStart + 1).split("&");
      const sourceQueryFlags = queryFlags.filter((flag) => QUERIES.has(flag));

      if (sourceQueryFlags.length === 0 && !queryFlags.some(hasQueryValue)) {
        return null;
      }

      if (sourceQueryFlags.length > 1) {
        this.error(
          `Source imports cannot use both ${QUERY_NAMES.join(" and ")}.`
        );
      }

      if (sourceQueryFlags.length !== queryFlags.length) {
        this.error(
          `Source imports only support the ${QUERY_NAMES.join(" and ")} query flags.`
        );
      }

      const resolved = await this.resolve(sourcePath, importer, {
        skipSelf: true,
      });

      if (
        !resolved ||
        resolved.external ||
        !resolved.id.startsWith(basePath) ||
        modules[resolved.id.slice(basePath.length)] === undefined
      ) {
        this.error(`Cannot import source from "${sourcePath}".`);
      }

      if (
        !SUPPORTED_EXTENSIONS.some((extension) =>
          resolved.id.endsWith(extension)
        )
      ) {
        this.error(
          "Source imports only support .js, .ts, .gjs, and .gts files."
        );
      }

      return `${VIRTUAL_PREFIX}${QUERIES.get(sourceQueryFlags[0])}:${resolved.id}`;
    },

    load(id) {
      if (!id.startsWith(VIRTUAL_PREFIX)) {
        return null;
      }

      const separator = id.indexOf(":", VIRTUAL_PREFIX.length);
      const mode = id.slice(VIRTUAL_PREFIX.length, separator);
      const sourceId = id.slice(separator + 1);
      const source = modules[sourceId.slice(basePath.length)];

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
  };
}

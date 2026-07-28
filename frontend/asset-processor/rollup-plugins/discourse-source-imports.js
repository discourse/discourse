import { Preprocessor } from "../content-tag";

const QUERIES = { "?source": "file", "?template-source": "template" };
const VIRTUAL_PREFIX = "\0discourse-source:";

const preprocessor = new Preprocessor();

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
      const query = Object.keys(QUERIES).find((candidate) =>
        source.endsWith(candidate)
      );

      if (!query) {
        return null;
      }

      const sourcePath = source.slice(0, -query.length);
      const resolved = await this.resolve(sourcePath, importer, {
        skipSelf: true,
      });

      if (!resolved || resolved.external || !resolved.id.startsWith(basePath)) {
        this.error(`Cannot import source from "${sourcePath}".`);
      }

      return `${VIRTUAL_PREFIX}${QUERIES[query]}:${resolved.id}`;
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

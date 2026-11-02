import MagicString from "magic-string";

export default function discourseTestModules({ basePath, modules }) {
  const testFiles = new Set(modules.map((path) => `${basePath}${path}`));
  return {
    name: "discourse-test-modules",
    transform: {
      order: "post",
      handler(code, id) {
        if (!testFiles.has(id) || !/-test\.(?:js|gjs|ts|gts)$/.test(id)) {
          return null;
        }

        const body = this.parse(code).body;
        if (body.some((node) => node.type.startsWith("Export"))) {
          this.error(`Test module must not export values: ${id}`);
        }
        const imports = body.filter(
          (node) => node.type === "ImportDeclaration"
        );
        const magic = new MagicString(code);
        for (const node of imports) {
          magic.remove(node.start, node.end);
        }
        magic.prepend(
          imports.map((node) => code.slice(node.start, node.end)).join("\n") +
            "\nexport default function () {\n"
        );
        magic.append("\n}\nexport const __discourseTestModule = true;\n");
        return {
          code: magic.toString(),
          map: magic.generateMap({ hires: true }),
        };
      },
    },
  };
}

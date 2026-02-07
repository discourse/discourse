import MagicString from "magic-string";
import { basename, dirname, join } from "path";

export default function discourseColocation({ basePath }) {
  return {
    name: "discourse-colocation",
    async resolveId(source, context) {
      let resolvedSource = source;
      if (source.startsWith(".")) {
        resolvedSource = join(dirname(context), source);
      }

      if (
        !(
          resolvedSource.startsWith(`${basePath}discourse/components/`) ||
          resolvedSource.startsWith(`${basePath}admin/components/`)
        )
      ) {
        return;
      }

      if (source.endsWith(".js")) {
        const hbs = await this.resolve(
          `./${basename(source).replace(/.js$/, ".hbs")}`,
          resolvedSource
        );
        const js = await this.resolve(source, context);

        if (!js && hbs) {
          return {
            id: resolvedSource,
            meta: {
              "rollup-hbs-plugin": {
                type: "template-only-component-js",
              },
            },
          };
        }
      }
    },

    load(id) {
      if (
        this.getModuleInfo(id)?.meta?.["rollup-hbs-plugin"]?.type ===
        "template-only-component-js"
      ) {
        return {
          code: `import templateOnly from '@ember/component/template-only';\nexport default templateOnly();\n`,
        };
      }
    },

    transform: {
      async handler(input, id) {
        if (
          !id.startsWith(`${basePath}discourse/components/`) &&
          !id.startsWith(`${basePath}admin/components/`)
        ) {
          return;
        }

        if (id.endsWith(".js")) {
          const relativeHbs = `./${basename(id).replace(/.js$/, ".hbs")}`;
          const hbs = await this.resolve(relativeHbs, id);

          if (hbs) {
            const s = new MagicString(input);
            s.prepend(
              `import template from '${relativeHbs}';\nconst __COLOCATED_TEMPLATE__ = template;\n`
            );

            return {
              code: s.toString(),
              map: s.generateMap({ hires: true }),
            };
          }
        }
      },
    },
  };
}

export default function discourseHbs() {
  return {
    name: "discourse-hbs",
    transform: {
      order: "pre",
      handler(input, id) {
        if (id.endsWith(".hbs")) {
          return {
            code: `
              import { hbs } from 'ember-cli-htmlbars';
              export default hbs(${JSON.stringify(input)}, { moduleName: ${JSON.stringify(id)} });

              import deprecated from 'discourse/lib/deprecated';
              deprecated(
                "The file '${id}' uses the deprecated .hbs extension. Refactor it to use '.gjs' instead.",
                {
                  id: "discourse.hbs-extension",
                  url: "https://meta.discourse.org/t/398896",
                } 
              );
            `,
            map: null,
          };
        }
      },
    },
  };
}

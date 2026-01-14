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
            `,
            map: null,
          };
        }
      },
    },
  };
}

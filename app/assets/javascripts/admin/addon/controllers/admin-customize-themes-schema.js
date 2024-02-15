import Controller from "@ember/controller";

export default class AdminCustomizeThemesSchemaController extends Controller {
  data = [
    {
      name: "item 1",
      children: [
        {
          name: "child 1-1",
          grandchildren: [
            {
              name: "grandchild 1-1-1",
            },
          ],
        },
        {
          name: "child 1-2",
          grandchildren: [
            {
              name: "grandchild 1-2-1",
            },
          ],
        },
      ],
    },
    {
      name: "item 2",
      children: [
        {
          name: "child 2-1",
          grandchildren: [
            {
              name: "grandchild 2-1-1",
            },
          ],
        },
        {
          name: "child 2-2",
          grandchildren: [
            {
              name: "grandchild 2-2-1",
            },
          ],
        },
      ],
    },
  ];

  schema = {
    name: "item",
    identifier: "name",
    properties: {
      name: {
        type: "string",
      },
      children: {
        type: "objects",
        schema: {
          name: "child",
          identifier: "name",
          properties: {
            name: {
              type: "string",
            },
            grandchildren: {
              type: "objects",
              schema: {
                name: "grandchild",
                identifier: "name",
                properties: {
                  name: {
                    type: "string",
                  },
                },
              },
            },
          },
        },
      },
    },
  };
}

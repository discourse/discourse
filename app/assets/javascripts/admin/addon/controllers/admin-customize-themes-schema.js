import Controller from "@ember/controller";

export default class AdminCustomizeThemesSchemaController extends Controller {
  data = [
    {
      name: "item 1",
      width: 143,
      is_valid: true,
      enum_prop: 11,
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
      width: 803,
      is_valid: false,
      enum_prop: 22,
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
      width: {
        type: "integer",
      },
      is_valid: {
        type: "boolean",
      },
      enum_prop: {
        type: "enum",
        choices: [11, 22],
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

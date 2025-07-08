import ThemeSettings from "admin/models/theme-settings";
import SiteSetting from "admin/models/site-setting";
export const SCHEMA_MODES = {
  THEME: "theme",
  SITE_SETTING: "SITE_SETTING",
};
export default function schemaAndData(version = 1, mode = SCHEMA_MODES.THEME) {
  let schema, data;

  if (version === 1) {
    schema = {
      name: "level1",
      identifier: "name",
      properties: {
        name: {
          type: "string",
        },
        children: {
          type: "objects",
          schema: {
            name: "level2",
            identifier: "name",
            properties: {
              name: {
                type: "string",
                label: "Level 2 Label",
                description: "Description for level 2",
              },
              grandchildren: {
                type: "objects",
                schema: {
                  name: "level3",
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
              {
                name: "grandchild 1-1-2",
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
              {
                name: "grandchild 2-1-2",
              },
            ],
          },
          {
            name: "child 2-2",
            grandchildren: [
              {
                name: "grandchild 2-2-1",
              },
              {
                name: "grandchild 2-2-2",
              },
              {
                name: "grandchild 2-2-3",
              },
              {
                name: "grandchild 2-2-4",
              },
            ],
          },
          {
            name: "child 2-3",
            grandchildren: [],
          },
        ],
      },
    ];
  } else if (version === 2) {
    schema = {
      name: "section",
      identifier: "name",
      properties: {
        name: {
          type: "string",
        },
        icon: {
          type: "string",
        },
        links: {
          type: "objects",
          schema: {
            name: "link",
            identifier: "text",
            properties: {
              text: {
                type: "string",
              },
              url: {
                type: "string",
              },
              icon: {
                type: "string",
              },
            },
          },
        },
      },
    };

    data = [
      {
        name: "nice section",
        icon: "arrow",
        links: [
          {
            text: "Privacy",
            url: "https://example.com",
            icon: "link",
          },
        ],
      },
      {
        name: "cool section",
        icon: "bell",
        links: [
          {
            text: "About",
            url: "https://example.com/about",
            icon: "asterisk",
          },
          {
            text: "Contact",
            url: "https://example.com/contact",
            icon: "phone",
          },
        ],
      },
    ];
  } else if (version === 3) {
    schema = {
      name: "something",
      identifier: "name",
      properties: {
        name: {
          type: "string",
        },
        integer_field: {
          type: "integer",
        },
        float_field: {
          type: "float",
        },
        boolean_field: {
          type: "boolean",
        },
        category_field: {
          type: "categories",
        },
        group_field: {
          type: "groups",
        },
        tags_field: {
          type: "tags",
        }
      },
    };
    data = [
      {
        name: "lamb",
        integer_field: 92,
        boolean_field: true,
      },
      {
        name: "cow",
        integer_field: 820,
        boolean_field: false,
      },
    ];
  } else {
    throw new Error("unknown fixture version");
  }

  if (mode === SCHEMA_MODES.SITE_SETTING) {
    return SiteSetting.create({
      schema: schema,
      value: data,
      setting: "objects_setting"
    })
  }

  return ThemeSettings.create({
    objects_schema: schema,
    value: data,
    setting: "objects_setting"
  });
}

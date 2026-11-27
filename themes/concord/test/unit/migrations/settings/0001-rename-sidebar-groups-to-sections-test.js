import { module, test } from "qunit";
import migrate from "../../../../migrations/settings/0001-rename-sidebar-groups-to-sections.js";

module(
  "Unit | Migrations | 0001-rename-sidebar-groups-to-sections",
  function () {
    test("moves sidebar_groups to sidebar_sections", function (assert) {
      const sections = [
        { name: "Gaming", channels: [{ type: "text", id: 1 }] },
      ];
      const result = migrate(new Map([["sidebar_groups", sections]]));

      assert.deepEqual(Object.fromEntries(result), {
        sidebar_sections: sections,
      });
    });

    test("leaves settings without sidebar_groups alone", function (assert) {
      const result = migrate(new Map([["include_tags", true]]));

      assert.deepEqual(Object.fromEntries(result), { include_tags: true });
    });
  }
);

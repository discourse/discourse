import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import SidebarSections, {
  channelKey,
} from "../../../discourse/lib/sidebar-sections.js";

const admin = { admin: true };

module("Unit | Lib | sidebar-sections", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.original = settings.sidebar_sections;
    this.saved = [];

    // What the server holds, which a change is applied to.
    this.stored = null;

    pretender.get("/admin/themes/:id.json", () =>
      response(200, {
        theme: {
          settings: [
            {
              setting: "sidebar_sections",
              value: this.stored ?? settings.sidebar_sections,
            },
          ],
        },
      })
    );

    pretender.put("/admin/themes/:id/setting", (request) => {
      const data = parsePostData(request.requestBody);
      const value = JSON.parse(data.value);
      this.saved.push({ name: data.name, value });
      this.stored = value;
      return response(200, {});
    });
  });

  hooks.afterEach(function () {
    settings.sidebar_sections = this.original;
  });

  function withSections(sections) {
    settings.sidebar_sections = sections;
    return new SidebarSections(admin);
  }

  test("only admins can edit", function (assert) {
    assert.true(new SidebarSections(admin).canEdit);
    assert.false(new SidebarSections({ moderator: true }).canEdit);
    assert.false(new SidebarSections(null).canEdit);
  });

  test("adds a channel to a new section at the end", async function (assert) {
    const sections = withSections([{ name: "Gaming", channels: [] }]);
    let changed = 0;
    sections.onChange = () => changed++;

    await sections.addChannel("Music", channelKey("text", 7));

    assert.deepEqual(sections.sections, [
      { name: "Gaming", channels: [] },
      { name: "Music", channels: [{ type: "text", id: 7 }] },
    ]);
    assert.deepEqual(this.saved, [
      { name: "sidebar_sections", value: sections.sections },
    ]);
    assert.deepEqual(settings.sidebar_sections, sections.sections);
    assert.strictEqual(changed, 1);
  });

  test("moves a channel between sections, and out of them", async function (assert) {
    const sections = withSections([
      { name: "Gaming", channels: [{ type: "text", id: 7 }] },
      { name: "Music", channels: [] },
    ]);

    await sections.moveChannel("text:7", "Music");
    assert.strictEqual(sections.sectionIndexOf("text:7"), 1);
    assert.deepEqual(sections.sections[0].channels, []);

    await sections.moveChannel("text:7", null);
    assert.strictEqual(sections.sectionIndexOf("text:7"), -1);
  });

  test("renames, reorders and deletes sections", async function (assert) {
    const sections = withSections([
      { name: "A", channels: [] },
      { name: "B", channels: [{ type: "forum", id: 3 }] },
    ]);

    await sections.renameSection(0, "First");
    await sections.moveSection(1, -1);
    assert.deepEqual(
      sections.sections.map((s) => s.name),
      ["B", "First"]
    );

    await sections.deleteSection(0);
    assert.deepEqual(sections.sections, [{ name: "First", channels: [] }]);
  });

  test("a change keeps sections saved elsewhere since the page loaded", async function (assert) {
    const sections = withSections([{ name: "A", channels: [] }]);
    this.stored = [
      { name: "A", channels: [] },
      { name: "Events", channels: [{ type: "forum", id: 4 }] },
    ];

    await sections.addChannel("A", "text:7");

    assert.deepEqual(sections.sections, [
      { name: "A", channels: [{ type: "text", id: 7 }] },
      { name: "Events", channels: [{ type: "forum", id: 4 }] },
    ]);
  });

  test("removing a channel in no section saves nothing", async function (assert) {
    const sections = withSections([{ name: "A", channels: [] }]);

    await sections.removeChannel("voice:9");

    assert.deepEqual(this.saved, []);
  });

  test("names are listed once each", function (assert) {
    const sections = withSections([
      { name: "A", channels: [] },
      { name: "A", channels: [] },
      { name: "B", channels: [] },
    ]);

    assert.deepEqual(sections.names, ["A", "B"]);
  });
});

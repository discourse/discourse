import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import ChannelPrivacy from "../../../discourse/lib/channel-privacy.js";

const everyone = { group_id: 0, group_name: "everyone", permission_type: 1 };
const staff = { group_id: 3, group_name: "staff", permission_type: 1 };
const designers = { group_id: 41, group_name: "designers", permission_type: 1 };
const readers = { group_id: 42, group_name: "readers", permission_type: 3 };

module("Unit | Lib | channel-privacy", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.site = getOwner(this).lookup("service:site");
    this.permissions = {};
    this.saved = null;
    this.updated = [];

    this.site.set("categories", []);
    this.site.updateCategory = (json) => this.updated.push(json);

    pretender.get("/c/:id/show.json", (request) =>
      response(200, {
        category: {
          group_permissions: this.permissions[request.params.id] || [everyone],
        },
      })
    );
    pretender.put("/categories/:id", (request) => {
      this.saved = parsePostData(request.requestBody);
      return response(200, { category: { id: Number(request.params.id) } });
    });
  });

  function forum(owner, category) {
    return new ChannelPrivacy(owner, {}).forLink({
      channelKey: `forum:${category.id}`,
      category,
    });
  }

  test("is offered only to people who can edit the category", function (assert) {
    const privacy = new ChannelPrivacy(getOwner(this), {});

    assert.strictEqual(
      privacy.forLink({ channelKey: "forum:5", category: { can_edit: false } }),
      null
    );
    assert.strictEqual(privacy.forLink({ channelKey: "dm:5" }), null);
  });

  test("reads a public category", async function (assert) {
    const loaded = await forum(getOwner(this), {
      id: 5,
      can_edit: true,
    }).load();

    assert.false(loaded.isPrivate);
    assert.deepEqual(loaded.groupIds, []);
    assert.deepEqual(loaded.required, []);
  });

  test("makes a category private, keeping groups' access levels", async function (assert) {
    this.permissions[5] = [staff, readers];
    const privacy = forum(getOwner(this), { id: 5, can_edit: true });
    const loaded = await privacy.load();

    assert.true(loaded.isPrivate);
    await privacy.save({ isPrivate: true, groupIds: [3, 42, 41] }, loaded);

    assert.deepEqual(this.saved.permissions, {
      staff: "1",
      readers: "3",
    });
    assert.strictEqual(this.updated.length, 1);
  });

  test("makes a category public", async function (assert) {
    this.permissions[5] = [staff];
    const privacy = forum(getOwner(this), { id: 5, can_edit: true });
    const loaded = await privacy.load();

    await privacy.save({ isPrivate: false, groupIds: [] }, loaded);

    assert.deepEqual(this.saved.permissions, { everyone: "1" });
  });

  test("leaves a public category's levels alone when it stays public", async function (assert) {
    this.permissions[5] = [{ ...everyone, permission_type: 3 }, staff];
    const privacy = forum(getOwner(this), { id: 5, can_edit: true });
    const loaded = await privacy.load();

    await privacy.save({ isPrivate: false, groupIds: [] }, loaded);

    assert.deepEqual(this.saved.permissions, { everyone: "3", staff: "1" });
  });

  test("keeps the groups its subcategories use", async function (assert) {
    this.site.set("categories", [
      { id: 6, parent_category_id: 5, displayName: "Mockups" },
    ]);
    this.permissions[6] = [designers];
    const privacy = forum(getOwner(this), { id: 5, can_edit: true });
    const loaded = await privacy.load();

    assert.deepEqual(loaded.required, [{ id: 41, name: "designers" }]);
    assert.strictEqual(loaded.publicSubcategory, null);

    await privacy.save({ isPrivate: true, groupIds: [] }, loaded);
    assert.deepEqual(this.saved.permissions, { designers: "1" });
  });

  test("knows when a public subcategory keeps it public", async function (assert) {
    this.site.set("categories", [
      { id: 6, parent_category_id: 5, displayName: "Stories" },
    ]);
    const loaded = await forum(getOwner(this), {
      id: 5,
      can_edit: true,
    }).load();

    assert.strictEqual(loaded.publicSubcategory, "Stories");
  });

  test("limits a subcategory to its private parent's groups", async function (assert) {
    const parent = {
      id: 10,
      slug: "private-events",
      displayName: "Private events",
    };
    this.permissions[10] = [staff];
    this.permissions[11] = [staff];
    const loaded = await forum(getOwner(this), {
      id: 11,
      can_edit: true,
      parentCategory: parent,
    }).load();

    assert.deepEqual([...loaded.allowedGroupIds], [3]);
    assert.deepEqual(loaded.privateParent, {
      name: "Private events",
      securityUrl: "/c/private-events/edit/security",
      groupNames: ["staff"],
    });
  });
});

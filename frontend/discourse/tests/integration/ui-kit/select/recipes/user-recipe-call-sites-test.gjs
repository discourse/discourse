import { tracked } from "@glimmer/tracking";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ComposerUserSelector from "discourse/components/composer-user-selector";
import InvitePanel from "discourse/components/invite-panel";
import ChangeOwnerModal from "discourse/components/modal/change-owner";
import CreateInvite from "discourse/components/modal/create-invite";
import GroupAddMembers from "discourse/components/modal/group-add-members";
import IgnoreDurationModal from "discourse/components/modal/ignore-duration-with-username";
import ModalContainer from "discourse/components/modal-container";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import DiscourseURL from "discourse/lib/url";
import GroupsNew from "discourse/templates/groups/new";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";

const USERS = [
  { username: "bob", name: "Bob Ross", avatar_template: "/a/bob/{size}.png" },
  { username: "alice", name: "Alice", avatar_template: "/a/a/{size}.png" },
  { username: "eviltrout", name: "Robin", avatar_template: "/a/e/{size}.png" },
];

const GROUPS = [{ name: "team", full_name: "The Team" }];

const GROUP_FLAGS = [
  "include_groups",
  "include_mentionable_groups",
  "include_messageable_groups",
];

/**
 * Answers user search like the server: by `term`, or by exact `usernames`, with groups only
 * when an include flag is sent. Records every request's params.
 */
function stubUserSearch() {
  const requests = [];
  pretender.get("/u/search/users", (request) => {
    const params = request.queryParams;
    requests.push(params);
    const withGroups = GROUP_FLAGS.some((flag) => params[flag] === "true");
    if (params.usernames) {
      const names = params.usernames.split(",").map((n) => n.toLowerCase());
      return response({
        users: USERS.filter((u) => names.includes(u.username)),
        groups: withGroups ? GROUPS.filter((g) => names.includes(g.name)) : [],
      });
    }
    const term = (params.term ?? "").toLowerCase();
    return response({
      users: USERS.filter((u) => u.username.includes(term)),
      groups: withGroups ? GROUPS.filter((g) => g.name.includes(term)) : [],
    });
  });
  return requests;
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

/** Shows `modal` with `model` the way the app does, in the modal container. */
async function showModal(owner, modal, model) {
  await render(<template><ModalContainer /></template>);
  owner.lookup("service:modal").show(modal, { model });
  await settled();
}

/** Opens `select`, types `term` and picks the row showing `text`. */
async function pick(select, term, text = term) {
  await select.open();
  await select.search(term);
  await click(optionNamed(text));
}

module(
  "Integration | ui-kit | select | recipes | user call sites",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    module("composer recipients", function () {
      test("writes picked users and groups as recipients, and remembers the groups", async function (assert) {
        const requests = stubUserSearch();
        const state = new (class {
          @tracked recipients = "";
        })();
        let selector;
        class Probe extends ComposerUserSelector {
          didInsertElement() {
            super.didInsertElement(...arguments);
            selector = this;
          }
        }

        await render(
          <template>
            <Probe @recipients={{state.recipients}} @topicId={{12}} />
          </template>
        );
        assert.dom(".d-select").exists();
        assert.dom(".select-kit").doesNotExist();

        const select = new DSelect();
        await pick(select, "bo", "bob");
        await select.search("te");
        await click(optionNamed("team"));

        assert.strictEqual(state.recipients, "bob,team");
        assert.deepEqual(selector._groups, ["team"], "the group is kept");
        assert.strictEqual(requests.at(-1).include_messageable_groups, "true");
        assert.strictEqual(requests.at(-1).topic_id, "12");
      });

      test("focuses the recipients picker when it is the focus target", async function (assert) {
        stubUserSearch();

        await render(
          <template><ComposerUserSelector @focusTarget="usernames" /></template>
        );

        assert.dom(".d-select [role='combobox']").isFocused();
      });
    });

    module("invite panel", function () {
      test("an address or a user enables the invite, clearing disables it", async function (assert) {
        stubUserSearch();
        const user = this.owner.lookup("service:store").createRecord("user", {
          details: { can_invite_via_email: true },
        });

        await render(
          <template><InvitePanel @inviteModel={{user}} /></template>
        );
        assert.dom(".d-select.invite-user-input").exists();
        assert.dom(".select-kit").doesNotExist();
        const select = new DSelect(".invite-user-input");
        assert.dom(".send-invite").isDisabled();

        await pick(select, "eviltrout@example.com");
        assert.dom(".send-invite").isEnabled();

        await select.clear();
        assert.dom(".send-invite").isDisabled();

        await pick(select, "bo", "bob");
        assert.dom(".send-invite").isEnabled();
      });
    });

    module("create invite", function () {
      test("sends the picked groups' ids, offering only groups people join by hand", async function (assert) {
        this.currentUser.set("moderator", true);
        this.owner.lookup("service:site").groups = [
          { id: 1, name: "admins", automatic: true },
          { id: 10, name: "support", automatic: false },
        ];
        let data;
        pretender.post("/invites", (request) => {
          data = parsePostData(request.requestBody);
          return response({ id: 5, link: "http://example.com/invites/x" });
        });
        const model = {};

        await render(
          <template>
            <CreateInvite @inline={{true}} @model={{model}} />
          </template>
        );
        await click(".edit-link-options");

        const select = new DSelect(".form-kit__field-custom .d-select");
        await select.open();
        assert.deepEqual(
          findAll("[role='option']").map((row) => row.dataset.value),
          ["10"]
        );
        await click(optionNamed("support"));
        await click(".save-invite");

        assert.deepEqual(data["group_ids[]"], ["10"]);
      });

      test("names the group field after its title", async function (assert) {
        this.currentUser.set("moderator", true);
        const accessibleName = await loadAccessibleName();
        const model = {};

        await render(
          <template>
            <CreateInvite @inline={{true}} @model={{model}} />
          </template>
        );
        await click(".edit-link-options");

        assert.strictEqual(
          accessibleName(
            find(".form-kit__field-custom .d-select [role='combobox']")
          ),
          i18n("user.invited.invite.add_to_groups")
        );
      });
    });

    module("group add members", function () {
      test("splits picked users and typed addresses", async function (assert) {
        stubUserSearch();
        this.currentUser.set("can_invite_to_forum", true);
        sinon.stub(this.owner.lookup("service:router"), "transitionTo");
        const group = { name: "team", addMembers: sinon.stub().resolves() };

        await showModal(this.owner, GroupAddMembers, group);
        const select = new DSelect(".group-add-members .d-select");
        await pick(select, "bo", "bob");
        await pick(select, "new@example.com");
        await click(".add");

        assert.deepEqual(group.addMembers.lastCall.args, [
          "bob",
          true,
          true,
          "new@example.com",
        ]);
      });
    });

    module("new group", function () {
      test("owner and member pickers are named by their labels and write usernames", async function (assert) {
        stubUserSearch();
        const accessibleName = await loadAccessibleName();
        const controller = {
          siteSettings: this.siteSettings,
          model: { visibility_level: 0 },
          splitOwnerUsernames: [],
          splitUsernames: [],
          updateOwnerUsernames: sinon.spy(),
          updateUsernames: sinon.spy(),
        };

        await render(
          <template><GroupsNew @controller={{controller}} /></template>
        );

        assert.strictEqual(
          accessibleName(find("#owner-selector")),
          i18n("admin.groups.add_owners")
        );
        assert.strictEqual(
          accessibleName(find("#member-selector")),
          i18n("groups.members.title")
        );

        await pick(new DSelect(".d-select:has(#member-selector)"), "bo", "bob");
        assert.deepEqual(controller.updateUsernames.lastCall.args[0], ["bob"]);
      });
    });

    module("change owner", function () {
      test("sends the picked username, and clearing disables the change", async function (assert) {
        stubUserSearch();
        sinon.stub(DiscourseURL, "routeTo");
        let data;
        pretender.post("/t/7/change-owner", (request) => {
          data = parsePostData(request.requestBody);
          return response({});
        });
        const model = {
          topic: { id: 7, url: "/t/x/7" },
          selectedPostIds: [3],
          selectedPostsCount: 1,
          deselectAll() {},
        };

        await showModal(this.owner, ChangeOwnerModal, model);
        const select = new DSelect();
        await pick(select, "bo", "bob");
        assert.dom(".change-ownership-modal .btn-primary").isEnabled();

        await select.clear();
        assert.dom(".change-ownership-modal .btn-primary").isDisabled();

        await pick(select, "al", "alice");
        await click(".change-ownership-modal .btn-primary");

        assert.strictEqual(data.username, "alice");
      });
    });

    module("ignore", function () {
      test("holds the picked username, clearing empties it, and the current user isn't offered", async function (assert) {
        stubUserSearch();
        const model = { actingUser: this.currentUser };

        await showModal(this.owner, IgnoreDurationModal, model);
        const picker = ".tracking-controls .d-select";
        const select = new DSelect(picker);
        await pick(select, "bo", "bob");
        assert.dom(picker).hasAttribute("data-value", "bob");

        await select.clear();
        assert.dom(picker).hasAttribute("data-value", "");

        await select.open();
        await select.search("evil");
        assert.dom("[role='option']").doesNotExist();
      });
    });
  }
);

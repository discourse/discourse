import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import BoardsBoardSettings from "discourse/plugins/boards/discourse/components/modal/boards-board-settings";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

module(
  "Integration | Component | BoardsBoardSettings | New and existing boards",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.fabricators = new BoardsFabricators(getOwner(this));
      this.model = {
        board: null,
        isNew: true,
        onSave: sinon.spy(),
        onDelete: () => {},
      };
      this.closeModal = sinon.spy();
    });

    test("slug placeholder is set to the slugified board name", async function (assert) {
      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      assert.dom(".discourse-boards-board-settings-modal").exists();
      await fillIn(".discourse-boards-editable-title__input", "Apollo Program");

      assert.strictEqual(
        formKit().field("slug").inputElement.placeholder,
        "apollo-program"
      );
    });

    test("reports confirmed access loss when the saved modal closes", async function (assert) {
      const group = this.site.groups[0];
      const board = this.fabricators.board();
      board.acl = [
        {
          type: "user",
          id: this.currentUser.id,
          permission: "owner",
          username: this.currentUser.username,
          display_name: this.currentUser.username,
        },
        {
          type: "group",
          id: group.id,
          permission: "manage",
          display_name: group.name,
        },
      ];
      this.model = { ...this.model, board, isNew: false };

      const dialog = getOwner(this).lookup("service:dialog");
      sinon.stub(dialog, "confirm").resolves(true);

      pretender.post("/access-control/evaluate.json", () =>
        response(422, {
          errors: ["You will lose permission to manage this board."],
          extras: {
            current_user_will_lose_permission: true,
            loss_warning_permissions: ["manage"],
          },
        })
      );

      await render(
        <template>
          <BoardsBoardSettings
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await formKit().submit();

      assert.true(this.model.onSave.calledOnce, "the board is saved");
      assert.deepEqual(
        this.closeModal.firstCall.args,
        [{ reloadAfterSave: true }],
        "the modal requests a reload after it closes"
      );
    });

    test("uses the board ownership capability for existing owner controls", async function (assert) {
      const board = this.fabricators.board();
      board.acl = [
        {
          type: "user",
          id: 7,
          permission: "owner",
          username: "martin",
          display_name: "martin",
        },
      ];
      board.can_manage_acl_owner = false;
      this.model = { ...this.model, board, isNew: false };

      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      const ownerPermission =
        '.d-access-control__row[data-row-type="user"][data-row-id="7"] .d-access-control__permission';
      assert
        .dom(ownerPermission)
        .isDisabled("keeps owner controls disabled without the capability");

      board.can_manage_acl_owner = true;

      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      assert
        .dom(ownerPermission)
        .isEnabled("enables owner controls with the capability");
    });

    test("does not offer additional owners while creating a board", async function (assert) {
      const board = this.fabricators.board();
      board.acl = [
        {
          type: "user",
          id: 7,
          permission: "edit",
          username: "martin",
          display_name: "martin",
        },
      ];
      this.model = { ...this.model, board };

      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      await click(
        '.d-access-control__row[data-row-type="user"][data-row-id="7"] .d-access-control__permission'
      );

      assert
        .dom('.d-access-control__permission-option[data-permission-id="owner"]')
        .doesNotExist("does not offer Owner during board creation");
    });

    test("splits owner users from ordinary ACL entries when saving", async function (assert) {
      const group = this.site.groups[0];
      const board = this.fabricators.board();
      board.acl = [
        {
          type: "user",
          id: 7,
          permission: "owner",
          username: "martin",
          display_name: "martin",
        },
        {
          type: "group",
          id: group.id,
          permission: "manage",
          display_name: group.name,
        },
        {
          type: "user",
          id: 8,
          permission: "owner",
          username: "sam",
          display_name: "sam",
        },
      ];
      board.can_manage_acl_owner = true;
      this.model = { ...this.model, board, isNew: false };
      pretender.post("/access-control/evaluate.json", () => response({}));

      await render(
        <template>
          <BoardsBoardSettings
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await formKit().submit();

      const savedBoard = this.model.onSave.firstCall.args[0];
      assert.deepEqual(
        savedBoard.owner_user_ids,
        [7, 8],
        "sends owner IDs through the dedicated ownership argument"
      );
      assert.deepEqual(
        savedBoard.acl,
        [
          {
            type: "group",
            id: group.id,
            permission: "manage",
            display_name: group.name,
          },
        ],
        "keeps only ordinary permissions in the ACL argument"
      );
    });

    test("does not submit an owner replacement when creating a board", async function (assert) {
      pretender.post("/access-control/evaluate.json", () => response({}));

      await render(
        <template>
          <BoardsBoardSettings
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await fillIn(".discourse-boards-editable-title__input", "New board");
      await formKit().submit();

      assert.false(
        Object.hasOwn(this.model.onSave.firstCall.args[0], "owner_user_ids"),
        "leaves initial ownership to the create service"
      );
    });

    test("does not submit owners without the ownership capability", async function (assert) {
      const board = this.fabricators.board();
      board.acl = [
        {
          type: "user",
          id: 7,
          permission: "owner",
          username: "martin",
          display_name: "martin",
        },
      ];
      board.can_manage_acl_owner = false;
      this.model = { ...this.model, board, isNew: false };
      pretender.post("/access-control/evaluate.json", () => response({}));

      await render(
        <template>
          <BoardsBoardSettings
            @closeModal={{this.closeModal}}
            @inline={{true}}
            @model={{this.model}}
          />
        </template>
      );

      await formKit().submit();

      assert.false(
        Object.hasOwn(this.model.onSave.firstCall.args[0], "owner_user_ids"),
        "does not request an ownership change"
      );
    });

    test("default ACL is created using manage board allowed groups and logged in users", async function (assert) {
      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      assert.dom(".discourse-boards-board-settings-modal").exists();

      assert.dom(".d-access-control__row.--group[data-row-id='1']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='2']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='5']").exists();
    });

    test("default ACL does not include logged_in_users twice if they are in boards_manage_board_allowed_groups", async function (assert) {
      this.siteSettings.boards_manage_board_allowed_groups = "1|2|5";
      await render(
        <template>
          <BoardsBoardSettings @inline={{true}} @model={{this.model}} />
        </template>
      );

      assert.dom(".discourse-boards-board-settings-modal").exists();

      assert.dom(".d-access-control__row.--group[data-row-id='1']").exists();
      assert.dom(".d-access-control__row.--group[data-row-id='2']").exists();
      assert
        .dom(".d-access-control__row.--group[data-row-id='5']")
        .exists({ count: 1 });
    });
  }
);

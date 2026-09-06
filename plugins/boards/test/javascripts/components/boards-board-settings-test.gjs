import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
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
          <BoardsBoardSettings @model={{this.model}} @inline={{true}} />
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
            @model={{this.model}}
            @closeModal={{this.closeModal}}
            @inline={{true}}
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

    test("default ACL is created using manage board allowed groups and logged in users", async function (assert) {
      await render(
        <template>
          <BoardsBoardSettings @model={{this.model}} @inline={{true}} />
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
          <BoardsBoardSettings @model={{this.model}} @inline={{true}} />
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

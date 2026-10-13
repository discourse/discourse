import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import BoardsArchive from "discourse/plugins/boards/discourse/components/modal/boards-archive";
import Board from "discourse/plugins/boards/discourse/models/board";

module("Integration | Component | BoardsArchive", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.model = {
      board: Board.create({ id: 1, archived: false, old_slug_used: false }),
      onSuccess: sinon.spy(),
    };
    this.closeModal = sinon.spy();
  });

  test("confirms archiving with a link to the boards list", async function (assert) {
    pretender.post("/boards/api/boards/1/archive", (request) => {
      assert.strictEqual(
        parsePostData(request.requestBody).client_id,
        getOwner(this).lookup("service:message-bus").clientId,
        "the initiating tab can ignore its own archive event"
      );
      return response({ board: { id: 1, archived: true } });
    });
    await render(
      <template>
        <BoardsArchive
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    assert
      .dom(".discourse-boards-archive-modal p")
      .hasText(
        'Are you sure you want to archive this board? You can see archived boards on the boards list by choosing "Archived" from the filter dropdown.',
        "the full confirmation is shown"
      );
    assert
      .dom(".discourse-boards-archive-modal p a")
      .hasAttribute("href", "/boards", "the list link is usable");
    assert
      .dom('[data-name="slug"]')
      .doesNotExist("archiving needs no slug input");
    await formKit().submit();
    assert.true(
      this.model.onSuccess.calledWith({ id: 1, archived: true }),
      "the updated board is returned to the viewer"
    );
    assert.true(this.closeModal.calledOnce, "the successful modal closes");
  });

  test("unarchives without a slug when the original remains available", async function (assert) {
    this.model.board.archived = true;
    pretender.post("/boards/api/boards/1/unarchive", () =>
      response({ board: { id: 1, archived: false } })
    );
    await render(
      <template>
        <BoardsArchive
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    assert
      .dom('[data-name="slug"]')
      .doesNotExist("an available original slug needs no input");
    await formKit().submit();
    assert.true(
      this.model.onSuccess.calledWith({ id: 1, archived: false }),
      "the board is restored"
    );
  });

  test("requires and submits a replacement slug when the original was reused", async function (assert) {
    Object.assign(this.model.board, { archived: true, old_slug_used: true });
    pretender.post("/boards/api/boards/1/unarchive", (request) => {
      assert.strictEqual(
        parsePostData(request.requestBody).client_id,
        getOwner(this).lookup("service:message-bus").clientId,
        "the initiating tab can ignore its own unarchive event"
      );
      assert.strictEqual(
        parsePostData(request.requestBody).slug,
        "restored-board",
        "the chosen slug is submitted"
      );
      return response({
        board: { id: 1, slug: "restored-board", archived: false },
      });
    });
    await render(
      <template>
        <BoardsArchive
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    assert
      .dom('[data-name="slug"] input')
      .exists("the replacement slug field is shown");
    await formKit().field("slug").fillIn("restored-board");
    await formKit().submit();
    assert.true(this.closeModal.calledOnce, "the successful modal closes");
  });
  test("asks for a replacement if the original slug is claimed while the modal is open", async function (assert) {
    this.model.board.archived = true;
    const dialog = getOwner(this).lookup("service:dialog");
    sinon.stub(dialog, "alert");
    pretender.post("/boards/api/boards/1/unarchive", () =>
      response(422, { errors: ["Slug has already been taken"] })
    );
    pretender.get("/boards/api/boards/1.json", () =>
      response({ board: { id: 1, archived: true, old_slug_used: true } })
    );
    await render(
      <template>
        <BoardsArchive
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.model}}
        />
      </template>
    );
    await formKit().submit();
    assert
      .dom('[data-name="slug"] input')
      .exists("updated slug availability enables a replacement");
    assert.false(this.closeModal.called, "the failed modal stays open");
    assert.false(this.model.onSuccess.called, "the board remains archived");
  });
});

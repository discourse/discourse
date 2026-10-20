import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { matchesExternalKind } from "discourse/lib/-internals/drag-and-drop/external-vocabulary";
import { matchesDragType } from "discourse/lib/-internals/drag-and-drop/vocabulary";
import {
  fileTransfer,
  textTransfer,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";

/**
 * The raw payload the underlying library hands its external callbacks, built
 * from a real `DataTransfer` so the kind predicates read the same `types` a
 * browser would report.
 */
function externalPayload(dataTransfer) {
  return {
    types: [...dataTransfer.types],
    items: [...dataTransfer.items],
    getStringData: (type) => dataTransfer.getData(type),
  };
}

function stringTransfer(mimeType, value) {
  const dataTransfer = new DataTransfer();
  dataTransfer.setData(mimeType, value);
  return dataTransfer;
}

module("Unit | Lib | drag-and-drop vocabulary", function (hooks) {
  setupTest(hooks);

  module("matchesDragType", function () {
    const source = (type) => ({ data: { type } });

    test("a single type engages only a drag of that type", function (assert) {
      assert.true(matchesDragType("row", source("row")), "the same type");
      assert.false(matchesDragType("row", source("card")), "a different type");
      assert.false(
        matchesDragType("row", { data: {} }),
        "a typeless source matches no filter"
      );
    });

    test("a list engages a drag of any type in it", function (assert) {
      assert.true(
        matchesDragType(["row", "card"], source("card")),
        "a list containing the type"
      );
      assert.false(
        matchesDragType(["row", "card"], source("other")),
        "a list without it"
      );
    });

    test("no filter engages every drag", function (assert) {
      assert.true(matchesDragType(undefined, source("row")), "omitted");
      assert.true(
        matchesDragType([], source("row")),
        "an empty list is the same as no filter"
      );
    });
  });

  module("matchesExternalKind", function () {
    const files = () => externalPayload(fileTransfer());
    const text = () => externalPayload(textTransfer());
    const html = () =>
      externalPayload(stringTransfer("text/html", "<b>dropped</b>"));
    const urls = () =>
      externalPayload(stringTransfer("text/uri-list", "https://example.com"));

    test("each kind engages only the payload that carries it", function (assert) {
      assert.true(matchesExternalKind("files", files()), "files: a file");
      assert.false(matchesExternalKind("files", text()), "files: text");

      assert.true(matchesExternalKind("text", text()), "text: text");
      assert.false(matchesExternalKind("text", files()), "text: a file");

      assert.true(matchesExternalKind("html", html()), "html: html");
      assert.false(matchesExternalKind("html", text()), "html: text");

      assert.true(matchesExternalKind("urls", urls()), "urls: a url list");
      assert.false(matchesExternalKind("urls", html()), "urls: html");
    });

    test("a list engages a payload carrying any kind in it", function (assert) {
      assert.true(
        matchesExternalKind(["files", "text"], text()),
        "a list containing the payload's kind"
      );
      assert.false(
        matchesExternalKind(["files", "html"], text()),
        "a list without it"
      );
    });

    test("no filter engages every external drag", function (assert) {
      assert.true(matchesExternalKind(undefined, files()), "omitted");
      assert.true(
        matchesExternalKind([], text()),
        "an empty list is the same as no filter"
      );
    });

    test("an unknown kind fails closed", function (assert) {
      assert.false(
        matchesExternalKind("images", files()),
        "a kind outside the vocabulary matches nothing rather than everything"
      );
      assert.false(
        matchesExternalKind(["images"], text()),
        "even inside a list"
      );
    });
  });
});

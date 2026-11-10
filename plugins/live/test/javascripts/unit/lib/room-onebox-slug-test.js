import { module, test } from "qunit";
import { roomSlug } from "discourse/plugins/live/discourse/initializers/live-room-onebox-presence";

function card(href) {
  const element = document.createElement("aside");
  element.innerHTML = `<h3 class="live-room-onebox__title"><a href="${href}">Room</a></h3>`;
  return element;
}

module("Live | Unit | Lib | room onebox slug", function () {
  const origin = window.location.origin;

  test("reads the slug from room and invite links on this site", function (assert) {
    assert.strictEqual(
      roomSlug(card(`${origin}/live/r/watercooler`)),
      "watercooler"
    );
    assert.strictEqual(
      roomSlug(card(`${origin}/live/r/town-hall/invited-by/sam?x=1`)),
      "town-hall"
    );
    assert.strictEqual(
      roomSlug(card(`${origin}/forum/live/r/watercooler`)),
      "watercooler",
      "subfolder installs"
    );
    assert.strictEqual(
      roomSlug(card("/live/r/watercooler")),
      "watercooler",
      "relative links"
    );
  });

  test("ignores other links", function (assert) {
    assert.strictEqual(roomSlug(card(`${origin}/t/some-topic/1`)), null);
    assert.strictEqual(roomSlug(card(`${origin}/live/rooms`)), null);
    assert.strictEqual(roomSlug(document.createElement("aside")), null);
    assert.strictEqual(roomSlug(card("http://[")), null, "malformed links");
  });
});

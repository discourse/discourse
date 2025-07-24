import { module, test } from "qunit";
import {
  addProgressDot,
  applyProgress,
  MIN_LETTERS_PER_INTERVAL,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-streamer/progress-handlers";

class FakeStreamUpdater {
  constructor() {
    this._streaming = true;
    this._raw = "";
    this._cooked = "";
    this._element = document.createElement("div");
  }

  get streaming() {
    return this._streaming;
  }

  set streaming(value) {
    this._streaming = value;
  }

  get cooked() {
    return this._cooked;
  }

  get raw() {
    return this._raw;
  }

  async setRaw(value) {
    this._raw = value;
    // just fake it, calling cook is tricky
    const cooked = `<p>${value}</p>`;
    await this.setCooked(cooked);
  }

  async setCooked(value) {
    this._cooked = value;
    this._element.innerHTML = value;
  }

  get element() {
    return this._element;
  }
}

module("Discourse AI | Unit | Lib | ai-streamer", function () {
  function confirmPlaceholder(html, expected, assert) {
    const element = document.createElement("div");
    element.innerHTML = html;

    const expectedElement = document.createElement("div");
    expectedElement.innerHTML = expected;

    addProgressDot(element);

    assert.equal(element.innerHTML, expectedElement.innerHTML);
  }

  test("inserts progress span in correct location for simple div", function (assert) {
    const html = "<div>hello world<div>hello 2</div></div>";
    const expected =
      "<div>hello world<div>hello 2<span class='progress-dot'></span></div></div>";

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts progress span in correct location for lists", function (assert) {
    const html = "<p>test</p><ul><li>hello world</li><li>hello world</li></ul>";
    const expected =
      "<p>test</p><ul><li>hello world</li><li>hello world<span class='progress-dot'></span></li></ul>";

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts correctly if list has blank html nodes", function (assert) {
    const html = `<ul>
<li><strong>Bold Text</strong>: To</li>

</ul>`;

    const expected = `<ul>
<li><strong>Bold Text</strong>: To<span class="progress-dot"></span></li>

</ul>`;

    confirmPlaceholder(html, expected, assert);
  });

  test("inserts correctly for tables", function (assert) {
    const html = `<table>
<tbody>
<tr>
<td>Bananas</td>
<td>20</td>
<td>$0.50</td>
</tr>
</tbody>
</table>
`;

    const expected = `<table>
<tbody>
<tr>
<td>Bananas</td>
<td>20</td>
<td>$0.50<span class="progress-dot"></span></td>
</tr>
</tbody>
</table>
`;

    confirmPlaceholder(html, expected, assert);
  });

  test("can perform delta updates", async function (assert) {
    const status = {
      startTime: Date.now(),
      raw: "some raw content",
      done: false,
    };

    const streamUpdater = new FakeStreamUpdater();

    let done = await applyProgress(status, streamUpdater);

    assert.false(done, "The update should not be done.");

    assert.strictEqual(
      streamUpdater.raw,
      status.raw.substring(0, MIN_LETTERS_PER_INTERVAL),
      "The raw content should delta update."
    );

    done = await applyProgress(status, streamUpdater);

    assert.false(done, "The update should not be done.");

    assert.strictEqual(
      streamUpdater.raw,
      status.raw.substring(0, MIN_LETTERS_PER_INTERVAL * 2),
      "The raw content should delta update."
    );

    // last chunk
    await applyProgress(status, streamUpdater);

    const innerHtml = streamUpdater.element.innerHTML;
    assert.strictEqual(
      innerHtml,
      "<p>some raw content</p>",
      "The cooked content should be updated."
    );

    status.done = true;
    status.cooked = "<p>updated cooked</p>";

    await applyProgress(status, streamUpdater);

    assert.strictEqual(
      streamUpdater.element.innerHTML,
      "<p>updated cooked</p>",
      "The cooked content should be updated."
    );
  });
});

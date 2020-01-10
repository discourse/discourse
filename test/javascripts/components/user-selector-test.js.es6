import componentTest from "helpers/component-test";

moduleForComponent("user-selector", { integration: true });

function paste(element, text) {
  let e = new Event("paste");
  e.clipboardData = { getData: () => text };
  element.dispatchEvent(e);
}

componentTest("pasting a list of usernames", {
  template: `{{user-selector usernames=usernames class="test-selector"}}`,

  beforeEach() {
    this.set("usernames", "evil,trout");
  },

  test(assert) {
    let element = find(".test-selector")[0];

    assert.equal(this.get("usernames"), "evil,trout");
    paste(element, "zip,zap,zoom");
    assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom");
    paste(element, "evil,abc,abc,abc");
    assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom,abc");

    this.set("usernames", "");
    paste(element, "names with spaces");
    assert.equal(this.get("usernames"), "names,with,spaces");

    this.set("usernames", null);
    paste(element, "@eviltrout,@codinghorror sam");
    assert.equal(this.get("usernames"), "eviltrout,codinghorror,sam");

    this.set("usernames", null);
    paste(element, "eviltrout\nsam\ncodinghorror");
    assert.equal(this.get("usernames"), "eviltrout,sam,codinghorror");
  }
});

componentTest("excluding usernames", {
  template: `{{user-selector usernames=usernames excludedUsernames=excludedUsernames class="test-selector"}}`,

  beforeEach() {
    this.set("usernames", "mark");
    this.set("excludedUsernames", ["jeff", "sam", "robin"]);
  },

  test(assert) {
    let element = find(".test-selector")[0];
    paste(element, "roman,penar,jeff,robin");
    assert.equal(this.get("usernames"), "mark,roman,penar");
  }
});

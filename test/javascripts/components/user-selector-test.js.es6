import componentTest from "helpers/component-test";

moduleForComponent("user-selector", { integration: true });

componentTest("pasting a list of usernames", {
  template: `{{user-selector usernames=usernames class="test-selector"}}`,

  beforeEach() {
    this.set("usernames", "evil,trout");
  },

  test(assert) {
    let element = find(".test-selector")[0];
    let paste = text => {
      let e = new Event("paste");
      e.clipboardData = { getData: () => text };
      element.dispatchEvent(e);
    };

    assert.equal(this.get("usernames"), "evil,trout");
    paste("zip,zap,zoom");
    assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom");
    paste("evil,abc,abc,abc");
    assert.equal(this.get("usernames"), "evil,trout,zip,zap,zoom,abc");

    this.set("usernames", "");
    paste("names with spaces");
    assert.equal(this.get("usernames"), "names,with,spaces");

    this.set("usernames", null);
    paste("@eviltrout,@codinghorror sam");
    assert.equal(this.get("usernames"), "eviltrout,codinghorror,sam");

    this.set("usernames", null);
    paste("eviltrout\nsam\ncodinghorror");
    assert.equal(this.get("usernames"), "eviltrout,sam,codinghorror");
  }
});

import componentTest from "helpers/component-test";
moduleForComponent("combo-box", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("default", {
  template: "{{combo-box content=items}}",
  beforeEach() {
    this.set("items", [{ id: 1, name: "hello" }, { id: 2, name: "world" }]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "hello"
    );
    assert.equal(
      this.subject
        .rowByValue(1)
        .name(),
      "hello"
    );
    assert.equal(
      this.subject
        .rowByValue(2)
        .name(),
      "world"
    );
  }
});

componentTest("with valueAttribute", {
  template: '{{combo-box content=items valueAttribute="value"}}',
  beforeEach() {
    this.set("items", [
      { value: 0, name: "hello" },
      { value: 1, name: "world" }
    ]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .rowByValue(0)
        .name(),
      "hello"
    );
    assert.equal(
      this.subject
        .rowByValue(1)
        .name(),
      "world"
    );
  }
});

componentTest("with nameProperty", {
  template: '{{combo-box content=items nameProperty="text"}}',
  beforeEach() {
    this.set("items", [{ id: 0, text: "hello" }, { id: 1, text: "world" }]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .rowByValue(0)
        .name(),
      "hello"
    );
    assert.equal(
      this.subject
        .rowByValue(1)
        .name(),
      "world"
    );
  }
});

componentTest("with an array as content", {
  template: "{{combo-box content=items value=value}}",
  beforeEach() {
    this.set("items", ["evil", "trout", "hat"]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .rowByValue("evil")
        .name(),
      "evil"
    );
    assert.equal(
      this.subject
        .rowByValue("trout")
        .name(),
      "trout"
    );
  }
});

componentTest("with value and none as a string", {
  template: '{{combo-box content=items none="test.none" value=value}}',
  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "none" };
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", "trout");
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .noneRow()
        .name(),
      "none"
    );
    assert.equal(
      this.subject
        .rowByValue("evil")
        .name(),
      "evil"
    );
    assert.equal(
      this.subject
        .rowByValue("trout")
        .name(),
      "trout"
    );
    assert.equal(
      this.subject
        .header()
        .name(),
      "trout"
    );
    assert.equal(this.value, "trout");

    await this.subject.selectNoneRow();

    assert.equal(this.value, null);
  }
});

componentTest("with value and none as an object", {
  template: "{{combo-box content=items none=none value=value}}",
  beforeEach() {
    this.set("none", { id: "something", name: "none" });
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", "evil");
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .noneRow()
        .name(),
      "none"
    );
    assert.equal(
      this.subject
        .rowByValue("evil")
        .name(),
      "evil"
    );
    assert.equal(
      this.subject
        .rowByValue("trout")
        .name(),
      "trout"
    );
    assert.equal(
      this.subject
        .header()
        .name(),
      "evil"
    );
    assert.equal(this.value, "evil");

    await this.subject.selectNoneRow();

    assert.equal(this.value, null);
  }
});

componentTest("with no value and none as an object", {
  template: "{{combo-box content=items none=none value=value}}",
  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "none" };
    this.set("none", { id: "something", name: "none" });
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", null);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "none"
    );
  }
});

componentTest("with no value and none string", {
  template: "{{combo-box content=items none=none value=value}}",
  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "none" };
    this.set("none", "test.none");
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", null);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "none"
    );
  }
});

componentTest("with no value and no none", {
  template: "{{combo-box content=items value=value}}",
  beforeEach() {
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", null);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "evil",
      "it sets the first row as value"
    );
  }
});

componentTest("with empty string as value", {
  template: "{{combo-box content=items value=value}}",
  beforeEach() {
    this.set("items", ["evil", "trout", "hat"]);
    this.set("value", "");
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "evil",
      "it sets the first row as value"
    );
  }
});

componentTest("with noneLabel", {
  template:
    "{{combo-box content=items allowAutoSelectFirst=false noneLabel=noneLabel}}",
  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "none" };
    this.set("items", ["evil", "trout", "hat"]);
    this.set("noneLabel", "test.none");
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject
        .header()
        .name(),
      "none",
      "it displays noneLabel as the header name"
    );
  }
});

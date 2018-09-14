import componentTest from "helpers/component-test";

moduleForComponent("mini-tag-chooser", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("default", {
  template: "{{mini-tag-chooser allowAny=true filterable=true tags=tags}}",

  beforeEach() {
    this.set("tags", ["jeff", "neil", "arpit"]);

    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/tags/filter/search", (params) => { //eslint-disable-line
      if (params.queryParams.q === "rég") {
        return response({
          results: [{ text: "régis", count: 5 }]
        });
      }

      if (params.queryParams.q === "joffrey") {
        return response({results: []});
      }

      return response({
        results: [{ text: "bianca", count: 3 }, { text: "régis", count: 5 }]
      });
    });
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      "bianca",
      "it has the correct tag"
    );

    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      "régis",
      "it has the correct tag"
    );

    await this.get("subject").fillInFilter("rég");
    await this.get("subject").keyboard("enter");
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis"],
      "it selects the tag"
    );

    await this.get("subject").expand();
    await this.get("subject").fillInFilter("joffrey");
    await this.get("subject").keyboard("enter");
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis"],
      "it creates the tag"
    );

    await click(
      this.get("subject")
        .el()
        .find(".selected-tag")
        .last()
    );
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit"],
      "it removes the tag"
    );
  }
});

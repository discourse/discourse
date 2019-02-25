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
    this.siteSettings.max_tag_length = 24;
    this.siteSettings.force_lowercase_tags = true;

    this.site.set("can_create_tag", true);
    this.set("tags", ["jeff", "neil", "arpit"]);

    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/tags/filter/search", (params) => { //eslint-disable-line
      if (params.queryParams.q === "régis") {
        return response({
          results: [{ text: "régis", count: 5 }]
        });
      }

      if (params.queryParams.q.toLowerCase() === "joffrey" || params.queryParams.q === "invalid'tag" || params.queryParams.q === "01234567890123456789012345") {
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

    await this.get("subject").fillInFilter("régis");
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
      ["jeff", "neil", "arpit", "régis", "joffrey"],
      "it creates the tag"
    );

    await this.get("subject").expand();
    await this.get("subject").fillInFilter("Joffrey");
    await this.get("subject").keyboard("enter");
    await this.get("subject").collapse();
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis", "joffrey"],
      "it does not allow case insensitive duplicate tags"
    );

    await this.get("subject").expand();
    await this.get("subject").fillInFilter("invalid' Tag");
    await this.get("subject").keyboard("enter");
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis", "joffrey", "invalid-tag"],
      "it strips invalid characters in tag"
    );

    await this.get("subject").expand();
    await this.get("subject").fillInFilter("01234567890123456789012345");
    await this.get("subject").keyboard("enter");
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis", "joffrey", "invalid-tag"],
      "it does not allow creating long tags"
    );

    await click(
      this.get("subject")
        .el()
        .find(".selected-tag")
        .last()
    );
    assert.deepEqual(
      this.get("tags"),
      ["jeff", "neil", "arpit", "régis", "joffrey"],
      "it removes the tag"
    );
  }
});

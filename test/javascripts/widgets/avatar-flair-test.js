import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("avatar-flair");

widgetTest("avatar flair with an icon", {
  template: '{{mount-widget widget="avatar-flair" args=args}}',
  beforeEach() {
    this.set("args", {
      primary_group_flair_url: "fa-bars",
      primary_group_flair_bg_color: "CC0000",
      primary_group_flair_color: "FFFFFF"
    });
  },
  test(assert) {
    assert.ok(find(".avatar-flair").length, "it has the tag");
    assert.ok(find("svg.d-icon-bars").length, "it has the svg icon");
    assert.equal(
      find(".avatar-flair").attr("style"),
      "background-color: #CC0000; color: #FFFFFF; ",
      "it has styles"
    );
  }
});

widgetTest("avatar flair with an image", {
  template: '{{mount-widget widget="avatar-flair" args=args}}',
  beforeEach() {
    this.set("args", {
      primary_group_flair_url: "/images/avatar.png"
    });
  },
  test(assert) {
    assert.ok(find(".avatar-flair").length, "it has the tag");
    assert.ok(find("svg").length === 0, "it does not have an svg icon");
  }
});

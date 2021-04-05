import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { resetFlair } from "discourse/lib/avatar-flair";

function setupSiteGroups(that) {
  that.site.groups = [
    {
      id: 1,
      name: "admins",
      flair_url: "fa-bars",
      flair_bg_color: "CC000A",
      flair_color: "FFFFFA",
    },
    {
      id: 2,
      name: "staff",
      flair_url: "fa-bars",
      flair_bg_color: "CC0005",
      flair_color: "FFFFF5",
    },
    {
      id: 3,
      name: "trust_level_1",
      flair_url: "fa-dice-one",
      flair_bg_color: "CC0001",
      flair_color: "FFFFF1",
    },
    {
      id: 4,
      name: "trust_level_2",
      flair_url: "fa-dice-two",
      flair_bg_color: "CC0002",
      flair_color: "FFFFF2",
    },
  ];
}

discourseModule(
  "Integration | Component | user-avatar-flair",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("avatar flair for admin user", {
      template: hbs`{{user-avatar-flair user=args}}`,
      beforeEach() {
        resetFlair();
        this.set("args", {
          admin: true,
          moderator: false,
          trust_level: 2,
        });
        setupSiteGroups(this);
      },
      afterEach() {
        resetFlair();
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(queryAll("svg.d-icon-bars").length, "it has the svg icon");
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #CC000A; color: #FFFFFA; ",
          "it has styles"
        );
      },
    });

    componentTest("avatar flair for moderator user with fallback to staff", {
      template: hbs`{{user-avatar-flair user=args}}`,
      beforeEach() {
        resetFlair();
        this.set("args", {
          admin: false,
          moderator: true,
          trust_level: 2,
        });
        setupSiteGroups(this);
      },
      afterEach() {
        resetFlair();
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(queryAll("svg.d-icon-bars").length, "it has the svg icon");
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #CC0005; color: #FFFFF5; ",
          "it has styles"
        );
      },
    });

    componentTest("avatar flair for trust level", {
      template: hbs`{{user-avatar-flair user=args}}`,
      beforeEach() {
        resetFlair();
        this.set("args", {
          admin: false,
          moderator: false,
          trust_level: 2,
        });
        setupSiteGroups(this);
      },
      afterEach() {
        resetFlair();
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(
          queryAll("svg.d-icon-dice-two").length,
          "it has the svg icon"
        );
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #CC0002; color: #FFFFF2; ",
          "it has styles"
        );
      },
    });

    componentTest("avatar flair for trust level with fallback", {
      template: hbs`{{user-avatar-flair user=args}}`,
      beforeEach() {
        resetFlair();
        this.set("args", {
          admin: false,
          moderator: false,
          trust_level: 3,
        });
        setupSiteGroups(this);
      },
      afterEach() {
        resetFlair();
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(
          queryAll("svg.d-icon-dice-two").length,
          "it has the svg icon"
        );
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #CC0002; color: #FFFFF2; ",
          "it has styles"
        );
      },
    });

    componentTest("avatar flair for primary group flair", {
      template: hbs`{{user-avatar-flair user=args}}`,
      beforeEach() {
        resetFlair();
        this.set("args", {
          admin: false,
          moderator: false,
          trust_level: 3,
          primary_group_flair_url: "fa-times",
          primary_group_flair_bg_color: "123456",
          primary_group_flair_color: "B0B0B0",
          primary_group_name: "Band Geeks",
        });
        setupSiteGroups(this);
      },
      afterEach() {
        resetFlair();
      },
      test(assert) {
        assert.ok(queryAll(".avatar-flair").length, "it has the tag");
        assert.ok(queryAll("svg.d-icon-times").length, "it has the svg icon");
        assert.equal(
          queryAll(".avatar-flair").attr("style"),
          "background-color: #123456; color: #B0B0B0; ",
          "it has styles"
        );
      },
    });
  }
);

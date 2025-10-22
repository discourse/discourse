import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import PostPolicy from "discourse/plugins/discourse-policy/discourse/components/post-policy";

function fabricatePost(options = {}) {
  return EmberObject.create({ id: 1, ...options });
}

function fabricatePolicy(options = {}) {
  return EmberObject.create({ accept: "ok", revoke: "not ok", ...options });
}

module(
  "Discourse Policy | Integration | Component | post-policy",
  function (hooks) {
    setupRenderingTest(hooks);

    test("empty post", async function (assert) {
      const self = this;

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".policy-footer").doesNotExist();
    });

    test("post#policy_can_accept", async function (assert) {
      const self = this;

      this.set("post", fabricatePost({ policy_can_accept: true }));
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".btn-accept-policy").exists();
      assert.dom(".btn-accept-policy").hasText(this.policy.accept);
    });

    test("post#policy_can_revoke", async function (assert) {
      const self = this;

      this.set("post", fabricatePost({ policy_can_revoke: true }));
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".btn-revoke-policy").exists();
      assert.dom(".btn-revoke-policy").hasText(this.policy.revoke);
    });

    test("post#policy_accepted_by_count", async function (assert) {
      const self = this;

      this.set("post", fabricatePost({ policy_accepted_by_count: 10 }));
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".toggle-accepted .user-count").hasText("10");
    });

    test("post#policy_not_accepted_by_count", async function (assert) {
      const self = this;

      this.set("post", fabricatePost({ policy_not_accepted_by_count: 10 }));
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".toggle-not-accepted .user-count").hasText("10");
    });

    test("no possible users", async function (assert) {
      const self = this;

      this.set(
        "post",
        fabricatePost({
          policy_accepted_by_count: 0,
          policy_not_accepted_by_count: 0,
          policy_stats: true,
        })
      );
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert
        .dom(".no-possible-users")
        .hasText(i18n("discourse_policy.no_possible_users"));
    });

    test("does not show 'no possible users' when no access to stats", async function (assert) {
      const self = this;

      this.set(
        "post",
        fabricatePost({
          policy_accepted_by_count: 0,
          policy_not_accepted_by_count: 0,
        })
      );
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".no-possible-users").doesNotExist();
    });

    test("toggle state", async function (assert) {
      const self = this;

      const acceptedByUsers = [
        { id: 1, username: "jeanne", avatar_template: "/images/avatar.png" },
      ];

      const notAcceptedByUsers = [
        { id: 2, username: "bob", avatar_template: "/images/avatar.png" },
        { id: 3, username: "alex", avatar_template: "/images/avatar.png" },
      ];

      this.set(
        "post",
        fabricatePost({
          policy_accepted_by: acceptedByUsers,
          policy_accepted_by_count: 1,
          policy_not_accepted_by: notAcceptedByUsers,
          policy_not_accepted_by_count: 3,
        })
      );
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      assert.dom(".users.accepted .avatar").exists({ count: 1 });
      assert.dom(".user-lists .toggle-accepted .user-count").hasText("1");
      assert.dom(".users.not-accepted").doesNotExist();

      await click(".toggle-not-accepted");

      assert.dom(".users.accepted").doesNotExist();
      assert.dom(".users.not-accepted .avatar").exists({ count: 2 });
      assert.dom(".user-lists .toggle-not-accepted .user-count").hasText("3");
      assert.dom(".load-more-users").hasText("+ 1");

      await click(".toggle-accepted");

      assert.dom(".users.accepted").exists();
      assert.dom(".users.not-accepted").doesNotExist();
    });

    test("accept policy", async function (assert) {
      const self = this;

      this.set("currentUser", {
        id: 1,
        username: "bob",
        avatar_template: "/images/avatar.png",
      });
      this.set(
        "post",
        fabricatePost({
          policy_can_accept: true,
          policy_not_accepted_by: [this.currentUser],
          policy_not_accepted_by_count: 1,
        })
      );
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      pretender.put("/policy/accept", () => {
        this.post.set("policy_accepted_by", this.currentUser);
        this.post.set("policy_accepted_by_count", 1);
        return response({});
      });

      await click(".btn-accept-policy");

      assert.dom(".btn-revoke-policy").exists();
      assert.dom(".user-lists .toggle-accepted .user-count").hasText("1");
    });

    test("revoke policy", async function (assert) {
      const self = this;

      this.set("currentUser", {
        id: 1,
        username: "bob",
        avatar_template: "/images/avatar.png",
      });
      this.set(
        "post",
        fabricatePost({
          policy_can_revoke: true,
          policy_accepted_by: [this.currentUser],
          policy_accepted_by_count: 1,
        })
      );
      this.set("policy", fabricatePolicy());

      await render(
        <template>
          <PostPolicy @post={{self.post}} @policy={{self.policy}} />
        </template>
      );

      pretender.put("/policy/unaccept", () => {
        this.post.set("policy_not_accepted_by", this.currentUser);
        this.post.set("policy_not_accepted_by_count", 1);
        return response({});
      });

      await click(".btn-revoke-policy");

      assert.dom(".btn-accept-policy").exists();
      assert.dom(".user-lists .toggle-not-accepted .user-count").hasText("1");
    });
  }
);

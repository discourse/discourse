import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VoteButton from "discourse/plugins/discourse-topic-voting/discourse/components/vote-button";

module(
  "Discourse Topic Voting | Integration | Component | vote-button",
  function (hooks) {
    setupRenderingTest(hooks);

    function configureCurrentUser(context) {
      context.currentUser.setProperties({
        vote_limit: 10,
        votes_exceeded: false,
        votes_left: 9,
      });
    }

    test("closed topics without a vote render the closed tooltip instead of the voting menu", async function (assert) {
      configureCurrentUser(this);
      this.topic = { closed: true, user_voted: false };
      this.addVote = () => assert.step("addVote");
      this.removeVote = () => assert.step("removeVote");

      await render(
        <template>
          <VoteButton
            @topic={{this.topic}}
            @addVote={{this.addVote}}
            @removeVote={{this.removeVote}}
          />
        </template>
      );

      assert
        .dom(".fk-d-tooltip__trigger[data-identifier='vote-closed-tooltip']")
        .exists();
      assert
        .dom(".fk-d-tooltip__trigger button.voting-wrapper__button")
        .isDisabled();
      assert
        .dom(".fk-d-menu__trigger[data-identifier='topic-voting-menu']")
        .doesNotExist();
      assert.verifySteps([]);
    });

    test("closed topics with an existing vote keep the remove vote path", async function (assert) {
      configureCurrentUser(this);
      this.topic = { closed: true, user_voted: true };
      this.removeVoteCalls = 0;
      this.addVote = () => {};
      this.removeVote = () => this.removeVoteCalls++;

      await render(
        <template>
          <VoteButton
            @topic={{this.topic}}
            @addVote={{this.addVote}}
            @removeVote={{this.removeVote}}
          />
        </template>
      );

      assert
        .dom(".fk-d-tooltip__trigger[data-identifier='vote-closed-tooltip']")
        .doesNotExist();
      assert
        .dom(".fk-d-menu__trigger[data-identifier='topic-voting-menu']")
        .exists();

      await click(".fk-d-menu__trigger[data-identifier='topic-voting-menu']");

      assert.dom("button.remove-vote").exists();

      await click("button.remove-vote");

      assert.strictEqual(this.removeVoteCalls, 1);
    });
  }
);

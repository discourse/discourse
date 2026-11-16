import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import SignupCta from "discourse/components/signup-cta";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | SignupCta", function (hooks) {
  setupRenderingTest(hooks);

  test("hides the prompt for the session", async function (assert) {
    const session = this.owner.lookup("service:session");
    session.setProperties({ hideSignupCta: false, showSignupCta: true });

    await render(<template><SignupCta /></template>);
    await click(".signup-cta .btn-default");

    assert
      .dom(".signup-cta h3")
      .hasText(
        i18n("signup_cta.hidden_for_session"),
        "confirms it is hidden for the session"
      );
    assert.true(session.get("hideSignupCta"), "records the choice");
  });

  test("turns a hidden prompt off when it goes away", async function (assert) {
    const session = this.owner.lookup("service:session");
    session.setProperties({ hideSignupCta: true, showSignupCta: true });
    this.set("shown", true);

    await render(
      <template>
        {{#if this.shown}}
          <SignupCta />
        {{/if}}
      </template>
    );

    this.set("shown", false);
    await settled();

    assert.false(session.get("showSignupCta"), "stops showing the prompt");
  });
});

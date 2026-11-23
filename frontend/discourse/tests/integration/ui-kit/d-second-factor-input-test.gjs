import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSecondFactorInput from "discourse/ui-kit/d-second-factor-input";

module("Integration | ui-kit | DSecondFactorInput", function (hooks) {
  setupRenderingTest(hooks);

  test("renders slots for a TOTP code", async function (assert) {
    const changes = [];
    const fills = [];
    const onChange = (value) => changes.push(value);
    const onFill = (value) => fills.push(value);

    await render(
      <template>
        <DSecondFactorInput
          id="totp"
          @onChange={{onChange}}
          @onFill={{onFill}}
          @secondFactorMethod={{SECOND_FACTOR_METHODS.TOTP}}
        />
      </template>
    );

    assert
      .dom(".d-otp input#totp.second-factor-token-input")
      .exists("attributes reach the code input");

    await fillIn("#totp", "123456");

    assert.deepEqual(changes, ["123456"], "@onChange gets the code");
    assert.deepEqual(fills, ["123456"], "@onFill gets the full code");
  });

  test("renders a text input for a backup code", async function (assert) {
    const changes = [];
    const onChange = (value) => changes.push(value);

    await render(
      <template>
        <DSecondFactorInput
          id="backup"
          @onChange={{onChange}}
          @secondFactorMethod={{SECOND_FACTOR_METHODS.BACKUP_CODE}}
        />
      </template>
    );

    assert.dom(".d-otp").doesNotExist("no slots are shown");
    assert
      .dom("input#backup.second-factor-token-input")
      .hasAttribute("maxlength", "32");

    await fillIn("#backup", "abcd1234abcd1234");

    assert.deepEqual(
      changes,
      ["abcd1234abcd1234"],
      "@onChange gets the typed code"
    );
  });
});

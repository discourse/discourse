import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  penaltyEffectDescription,
  penaltyIcon,
  penaltyPastTense,
} from "discourse/lib/reviewable-penalty";
import { i18n } from "discourse-i18n";

const SILENCE = { kind: "silence" };
const SUSPENSION = { kind: "suspension" };

module("Unit | Lib | reviewable-penalty", function (hooks) {
  setupTest(hooks);

  test("penaltyPastTense", function (assert) {
    assert.strictEqual(penaltyPastTense("silence"), "silenced");
    assert.strictEqual(penaltyPastTense("suspension"), "suspended");
    assert.strictEqual(penaltyPastTense("nope"), undefined);
  });

  test("penaltyIcon", function (assert) {
    assert.strictEqual(penaltyIcon("silence"), "microphone-slash");
    assert.strictEqual(penaltyIcon("suspension"), "ban");
    assert.strictEqual(penaltyIcon("nope"), undefined);
  });

  test("penaltyEffectDescription is absent without an effect or a penalty", function (assert) {
    assert.strictEqual(penaltyEffectDescription(null, [SILENCE]), null);
    assert.strictEqual(penaltyEffectDescription({}, [SILENCE]), null);
    assert.strictEqual(
      penaltyEffectDescription({ penalty_effect: "retains_penalty" }, []),
      null
    );
  });

  test("penaltyEffectDescription names the penalty an action lifts", function (assert) {
    assert.strictEqual(
      penaltyEffectDescription({ penalty_effect: "lifts_penalty" }, [SILENCE]),
      i18n("review.author_penalty.effect.lifts_silence")
    );
  });

  test("penaltyEffectDescription names every penalty an action leaves behind", function (assert) {
    const retains = { penalty_effect: "retains_penalty" };

    assert.strictEqual(
      penaltyEffectDescription(retains, [SILENCE]),
      i18n("review.author_penalty.effect.retains_silence")
    );

    assert.strictEqual(
      penaltyEffectDescription(retains, [SUSPENSION]),
      i18n("review.author_penalty.effect.retains_suspension")
    );

    assert.strictEqual(
      penaltyEffectDescription(retains, [SILENCE, SUSPENSION]),
      i18n("review.author_penalty.effect.retains_silence_and_suspension")
    );
  });
});

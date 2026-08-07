import Service, { service } from "@ember/service";
import { CREATE_TOPIC } from "discourse/models/composer";
import { buildEventSkeleton } from "../lib/raw-event-helper";

// Matches an opening `[event` BBCode tag — `[event ` (with attributes) or
// `[event]` (bare). Used to detect when the user has added/removed the block.
const EVENT_OPEN_TAG = /\[event(\s|\])/;

// Drives the composer's "event mode" from composer appEvents.
// State lives on the composer model. This only decides when it triggers.
export default class CreateEventComposer extends Service {
  @service appEvents;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "composer:category-changed",
      this,
      this.onCategoryChanged
    );
    this.appEvents.on("composer:reply-changed", this, this.syncEventMode);
    this.appEvents.on("composer:reply-reloaded", this, this.syncEventMode);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "composer:category-changed",
      this,
      this.onCategoryChanged
    );
    this.appEvents.off("composer:reply-changed", this, this.syncEventMode);
    this.appEvents.off("composer:reply-reloaded", this, this.syncEventMode);
  }

  eligible(composer) {
    return (
      composer?.action === CREATE_TOPIC &&
      composer?.user?.can_create_discourse_post_event &&
      composer?.category?.isType?.("events")
    );
  }

  enterEventMode(composer) {
    if (composer.creatingEvent) {
      return;
    }
    composer.set("creatingEvent", true);
    // `actionTitle`, `saveLabel`, `saveIcon` are @computed on `model.category`
    // and don't re-fire when only `creatingEvent` changes.
    composer.notifyPropertyChange("category");

    if (EVENT_OPEN_TAG.test(composer.reply || "")) {
      return;
    }

    const reply = (composer.reply || "").trim();
    const template = (composer.category?.topic_template || "").trim();
    const skeleton = buildEventSkeleton(composer.user);

    if (!reply || reply === template) {
      composer.set("reply", skeleton);
    } else {
      composer.appendText(skeleton, null, { new_line: true });
    }
    // Snapshot the exact reply we just produced so we can recognise it as
    // "untouched" on exit. Any edit (attribute change, surrounding text)
    // makes this comparison fail and changes are preserved.
    composer._insertedEventReply = composer.reply;
  }

  exitEventMode(composer) {
    if (!composer.creatingEvent) {
      return;
    }
    composer.set("creatingEvent", false);
    composer.notifyPropertyChange("category");

    if (composer.reply === composer._insertedEventReply) {
      composer.set("reply", "");
    }
    composer._insertedEventReply = null;
  }

  // Guards auto-enter so a restored draft without an [event] block is left alone
  maybeAutoEnterEventMode(composer) {
    if (composer.creatingEvent || !this.eligible(composer)) {
      return;
    }
    const reply = (composer.reply || "").trim();
    const template = (composer.category?.topic_template || "").trim();
    const hasEventTag = EVENT_OPEN_TAG.test(composer.reply || "");
    if (!hasEventTag && reply && reply !== template) {
      return;
    }
    this.enterEventMode(composer);
  }

  onCategoryChanged(composer) {
    if (composer.creatingEvent && !this.eligible(composer)) {
      this.exitEventMode(composer);
      // The unedited skeleton blocked `applyTopicTemplate` from populating the
      // destination category's template; now that exit has cleared it, apply
      // the template the user would have seen had they never been in event mode.
      composer.applyTopicTemplate(null, composer.categoryId);
    }
    this.maybeAutoEnterEventMode(composer);
  }

  syncEventMode(composer) {
    const hasEventTag = EVENT_OPEN_TAG.test(composer.reply || "");
    // Exit if the block is gone or the composer is no longer eligible — the
    // eligibility check also clears a stale flag left on a reused model, which
    // core's `clearState` no longer resets.
    if (composer.creatingEvent && (!hasEventTag || !this.eligible(composer))) {
      this.exitEventMode(composer);
    } else if (
      !composer.creatingEvent &&
      hasEventTag &&
      this.eligible(composer)
    ) {
      this.enterEventMode(composer);
    }
  }
}

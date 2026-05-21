/* eslint-disable ember/no-observers */
import { tracked } from "@glimmer/tracking";
import { addObserver, removeObserver } from "@ember/object/observers";
import { withPluginApi } from "discourse/lib/plugin-api";
import { CREATE_TOPIC } from "discourse/models/composer";
import I18n, { i18n } from "discourse-i18n";
import { buildEventSkeleton } from "../lib/raw-event-helper";

// Matches an opening `[event` BBCode tag — `[event ` (with attributes) or
// `[event]` (bare). Used to detect when the user has removed the event block.
const EVENT_OPEN_TAG = /\[event(\s|\])/;
const EVENT_ICON = "calendar-day";

function eligible(composer) {
  return (
    composer?.action === CREATE_TOPIC &&
    composer?.user?.can_create_discourse_post_event &&
    composer?.category?.isType?.("events")
  );
}

function enterEventMode(composer) {
  if (composer.creatingEvent) {
    return;
  }
  composer.set("creatingEvent", true);
  // `actionTitle`, `saveLabel`, `saveIcon` are @computed on `model.category`
  // and don't re-fire when only `creatingEvent` changes. Nudge dependents
  // so the heading and submit-button label/icon pick up the customizations.
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

// Guards auto-enter so a restored draft (or other in-flight content) without
// an [event] block is left alone — the user can opt in via the dropdown.
function maybeAutoEnterEventMode(composer) {
  if (composer.creatingEvent || !eligible(composer)) {
    return;
  }
  const reply = (composer.reply || "").trim();
  const template = (composer.category?.topic_template || "").trim();
  const hasEventTag = EVENT_OPEN_TAG.test(composer.reply || "");
  if (!hasEventTag && reply && reply !== template) {
    return;
  }
  enterEventMode(composer);
}

function exitEventMode(composer) {
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

function initializeCreateEventComposerAction(api) {
  api.modifyClass(
    "model:composer",
    (Superclass) =>
      class extends Superclass {
        @tracked creatingEvent = false;
        _insertedEventReply = null;

        init() {
          super.init(...arguments);
          addObserver(this, "reply", this, "_maybeToggleEventMode");
        }

        willDestroy() {
          removeObserver(this, "reply", this, "_maybeToggleEventMode");
          super.willDestroy?.(...arguments);
        }

        clearState() {
          super.clearState(...arguments);
          this.creatingEvent = false;
          this._insertedEventReply = null;
        }

        applyTopicTemplate(oldCategoryId, categoryId) {
          if (this.creatingEvent && !eligible(this)) {
            exitEventMode(this);
          }
          super.applyTopicTemplate(oldCategoryId, categoryId);
          maybeAutoEnterEventMode(this);
        }

        _maybeToggleEventMode() {
          const hasEventTag = EVENT_OPEN_TAG.test(this.reply || "");
          if (this.creatingEvent && !hasEventTag) {
            exitEventMode(this);
          } else if (!this.creatingEvent && hasEventTag && eligible(this)) {
            enterEventMode(this);
          }
        }
      }
  );

  api.addComposerAction({
    id: "create_event",
    label: "discourse_post_event.composer_actions.create_event.label",
    description: "discourse_post_event.composer_actions.create_event.desc",
    icon: EVENT_ICON,
    condition: (component) => {
      const composer = component.composerModel;
      return eligible(composer) && !composer.creatingEvent;
    },
    action: (composer) => enterEventMode(composer),
  });

  api.addComposerAction({
    id: "create_regular_topic",
    label: "discourse_post_event.composer_actions.create_topic.label",
    description: "discourse_post_event.composer_actions.create_topic.desc",
    icon: "plus",
    condition: (component) => {
      const composer = component.composerModel;
      return eligible(composer) && composer.creatingEvent;
    },
    action: (composer) => exitEventMode(composer),
  });

  api.customizeComposerText({
    actionTitle(model) {
      if (!model.creatingEvent) {
        return;
      }
      const key = "discourse_post_event.composer.action_title";
      if (I18n.lookup(key) !== undefined) {
        return i18n(key);
      }
    },
    saveLabel(model) {
      if (model.creatingEvent) {
        return "discourse_post_event.composer.create_event_button";
      }
    },
    saveIcon(model) {
      if (model.creatingEvent) {
        return EVENT_ICON;
      }
    },
    titlePlaceholder(model) {
      if (model.creatingEvent) {
        return "discourse_post_event.composer.event_title_placeholder";
      }
    },
  });
}

export default {
  name: "add-create-event-composer-action",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.discourse_post_event_enabled) {
      return;
    }
    withPluginApi(initializeCreateEventComposerAction);
  },
};

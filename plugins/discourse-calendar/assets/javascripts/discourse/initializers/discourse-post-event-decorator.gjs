import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ComposerEventEditor from "discourse/plugins/discourse-calendar/discourse/components/composer-event-editor";
import DiscoursePostEvent from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event";
import DiscoursePostEventOneboxPreview from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/onebox-preview";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";

const ComposerEventEditorTemplate = <template>
  <ComposerEventEditor />
</template>;

function _invalidEventPreview(eventContainer) {
  eventContainer.classList.add(
    "discourse-post-event-preview",
    "alert",
    "alert-error"
  );
  eventContainer.classList.remove("discourse-post-event");
  eventContainer.innerText = i18n(
    "discourse_post_event.preview.more_than_one_event"
  );
}

function _decorateEventOneboxes(cooked, helper) {
  const oneboxes = helper.getModel()?.event_oneboxes;
  if (!oneboxes) {
    return;
  }

  cooked
    .querySelectorAll(
      "aside.quote[data-topic][data-post='1']:not([data-username])"
    )
    .forEach((aside) => {
      const topicId = parseInt(aside.dataset.topic, 10);
      const data = topicId && oneboxes[topicId];
      if (!data) {
        return;
      }

      const wrapper = document.createElement("div");
      wrapper.className = "discourse-post-event-onebox";
      aside.replaceWith(wrapper);

      const event = DiscoursePostEventEvent.create(data);
      helper.renderGlimmer(
        wrapper,
        <template>
          <DiscoursePostEvent @event={{event}} @linkToPost={{true}} />
        </template>
      );
    });
}

function _decorateEventPreviewOneboxes(cooked, helper) {
  // In the composer preview there's no post model / preloaded data, so we fetch
  // the event by topic id and render a read-only card. The original quote is
  // passed as a fallback so non-event links (and the loading state) keep showing
  // the normal onebox.
  cooked
    .querySelectorAll(
      "aside.quote[data-topic][data-post='1']:not([data-username])"
    )
    .forEach((aside) => {
      const topicId = parseInt(aside.dataset.topic, 10);
      if (!topicId) {
        return;
      }

      const fallbackHtml = aside.outerHTML;
      const wrapper = document.createElement("div");
      wrapper.className = "discourse-post-event-onebox";
      aside.replaceWith(wrapper);

      helper.renderGlimmer(
        wrapper,
        <template>
          <DiscoursePostEventOneboxPreview
            @topicId={{topicId}}
            @fallbackHtml={{fallbackHtml}}
          />
        </template>
      );
    });
}

function _decorateEventPreview(api, cooked, helper) {
  const eventContainers = cooked.querySelectorAll(".discourse-post-event");

  eventContainers.forEach((eventContainer, index) => {
    if (index > 0) {
      _invalidEventPreview(eventContainer);
      return;
    }

    eventContainer.innerHTML = "";
    helper.renderGlimmer(eventContainer, ComposerEventEditorTemplate);
  });
}

function initializeDiscoursePostEventDecorator(api) {
  api.addTrackedPostProperties("event_oneboxes");

  api.decorateCookedElement(
    (cooked, helper) => {
      if (cooked.classList.contains("d-editor-preview")) {
        _decorateEventPreview(api, cooked, helper);
        if (helper) {
          _decorateEventPreviewOneboxes(cooked, helper);
        }
        return;
      }

      if (helper) {
        _decorateEventOneboxes(cooked, helper);

        const post = helper.getModel();

        if (!post?.event) {
          return;
        }

        const postEventNode = cooked.querySelector(".discourse-post-event");

        if (!postEventNode) {
          return;
        }

        let hideLivestreamVideo = false;
        if (
          postEventNode.parentElement.classList.contains(
            "post__contents-cooked-quote"
          )
        ) {
          hideLivestreamVideo = true;
        }

        const wrapper = document.createElement("div");
        postEventNode.before(wrapper);

        const event = DiscoursePostEventEvent.create(post.event);

        helper.renderGlimmer(
          wrapper,
          <template>
            <DiscoursePostEvent
              @event={{event}}
              @post={{post}}
              @hideLivestreamVideo={{hideLivestreamVideo}}
            />
          </template>
        );
      }
    },
    {
      id: "discourse-post-event-decorator",
    }
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_auto_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_calendar.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_predefined_attendance_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.before_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.after_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.ongoing_event_reminder",
    "calendar-day"
  );
}

export default {
  name: "discourse-post-event-decorator",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi(initializeDiscoursePostEventDecorator);
    }
  },
};

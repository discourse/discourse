import Component from "@glimmer/component";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { applyValueTransformer } from "discourse/lib/transformer";
import PostMetadataUserNotes from "../components/post-metadata-user-notes";
import { showUserNotes, updatePostUserNotesCount } from "../lib/user-notes";

/**
 * Plugin initializer for enabling user notes functionality
 */
export default {
  name: "enable-user-notes",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const currentUser = container.lookup("service:current-user");

    if (!siteSettings.user_notes_enabled || !currentUser?.staff) {
      return;
    }

    withPluginApi((api) => {
      customizePost(api, container);
      customizePostMenu(api, container);
      handleReviewableNoteCreation(api);
    });
  },
};

/**
 * Customizes how user notes are displayed in posts
 *
 * @param {Object} api - Plugin API instance
 * @param {Object} container - Container instance
 */
function customizePost(api, container) {
  const siteSettings = container.lookup("service:site-settings");

  const placement = applyValueTransformer(
    "user-notes-icon-placement",
    siteSettings.user_notes_icon_placement
  );

  // Component to display user notes flair icon
  class UserNotesPostMetadataFlairIcon extends Component {
    static shouldRender(args) {
      return args.post?.user_custom_fields?.user_notes_count > 0;
    }

    <template><PostMetadataUserNotes @post={{@post}} /></template>
  }

  // Handle placement next to avatar
  if (placement === "avatar") {
    api.renderAfterWrapperOutlet(
      "poster-avatar",
      UserNotesPostMetadataFlairIcon
    );
  }
  // Handle placement next to username
  else if (placement === "name") {
    // Mobile-specific version
    class MobileUserNotesIcon extends UserNotesPostMetadataFlairIcon {
      static shouldRender(args, context) {
        return context.site.mobileView && super.shouldRender(args);
      }
    }

    // Desktop-specific version
    class DesktopUserNotesIcon extends UserNotesPostMetadataFlairIcon {
      static shouldRender(args, context) {
        return !context.site.mobileView && super.shouldRender(args);
      }
    }

    api.renderBeforeWrapperOutlet(
      "post-meta-data-poster-name",
      MobileUserNotesIcon
    );
    api.renderAfterWrapperOutlet(
      "post-meta-data-poster-name",
      DesktopUserNotesIcon
    );
  }
}

/**
 * Adds user notes button to post admin menu
 *
 * @param {Object} api - Plugin API instance
 * @param {Object} container - Container instance
 */
function customizePostMenu(api, container) {
  const store = container.lookup("service:store");

  api.addPostAdminMenuButton((attrs) => {
    return {
      icon: "pen-to-square",
      label: "user_notes.attach",
      action: (post) => {
        showUserNotes(
          store,
          attrs.user_id,
          (count) => {
            updatePostUserNotesCount(post, count);
          },
          { postId: attrs.id }
        );
      },
      secondaryAction: "closeAdminMenu",
      className: "add-user-note",
    };
  });
}

/**
 * Optionally creates a user note when a reviewable note is created.
 *
 * @param {Object} api - Plugin API instance
 */
function handleReviewableNoteCreation(api) {
  api.onAppEvent(
    "reviewablenote:created",
    async (data, reviewable, formApi) => {
      if (!data.copy_note_to_user || !reviewable.target_created_by) {
        return;
      }

      try {
        await ajax("/user_notes", {
          type: "POST",
          data: {
            user_note: {
              user_id: reviewable.target_created_by.id,
              raw: data.content.trim(),
            },
          },
        });

        formApi.set("copy_note_to_user", false);
      } catch (error) {
        popupAjaxError(error);
      }
    }
  );
}

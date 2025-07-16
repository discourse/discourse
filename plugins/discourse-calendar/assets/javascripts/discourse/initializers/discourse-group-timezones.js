import $ from "jquery";
import { getRegister } from "discourse/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import WidgetGlue from "discourse/widgets/glue";

export default {
  name: "discourse-group-timezones",

  initialize() {
    withPluginApi("0.8.7", (api) => {
      let _glued = [];

      function cleanUp() {
        _glued.forEach((g) => g.cleanUp());
        _glued = [];
      }

      function _attachWidget(container, options) {
        const glue = new WidgetGlue(
          "discourse-group-timezones",
          getRegister(api),
          options
        );
        glue.appendTo(container);
        _glued.push(glue);
      }

      function _attachGroupTimezones($elem, post) {
        const $groupTimezones = $(".group-timezones", $elem);

        if (!$groupTimezones.length) {
          return;
        }

        $groupTimezones.each((idx, groupTimezone) => {
          const group = groupTimezone.getAttribute("data-group");
          if (!group) {
            throw "[group] attribute is necessary when using timezones.";
          }

          const members = (post.get("group_timezones") || {})[group] || [];

          _attachWidget(groupTimezone, {
            id: `${post.id}-${idx}`,
            members,
            group,
            usersOnHoliday:
              api.container.lookup("service:site").users_on_holiday || [],
            size: groupTimezone.getAttribute("data-size") || "medium",
          });
        });
      }

      function _attachPostWithGroupTimezones($elem, helper) {
        if (helper) {
          const post = helper.getModel();

          if (post) {
            api.preventCloak(post.id);
            _attachGroupTimezones($elem, post);
          }
        }
      }

      api.decorateCooked(_attachPostWithGroupTimezones, {
        id: "discourse-group-timezones",
      });

      api.cleanupStream(cleanUp);
    });
  },
};

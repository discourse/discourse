import { apiInitializer } from "discourse/lib/api";
import GroupTimezones from "../components/group-timezones";

const GroupTimezonesShim = <template>
  <GroupTimezones
    @members={{@data.members}}
    @group={{@data.group}}
    @size={{@data.size}}
  />
</template>;

export default apiInitializer((api) => {
  api.decorateCookedElement((element, helper) => {
    element.querySelectorAll(".group-timezones").forEach((el) => {
      const post = helper.getModel();

      if (!post) {
        return;
      }

      const group = el.dataset.group;
      if (!group) {
        throw new Error(
          "Group timezone element is missing 'data-group' attribute"
        );
      }

      helper.renderGlimmer(el, GroupTimezonesShim, {
        group,
        members: (post.group_timezones || {})[group] || [],
        size: el.dataset.size || "medium",
      });
    });
  });
});

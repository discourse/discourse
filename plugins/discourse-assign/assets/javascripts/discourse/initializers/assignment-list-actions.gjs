import { withPluginApi } from "discourse/lib/plugin-api";
import AssignedTopicListColumn from "../components/assigned-topic-list-column";

const ASSIGN_LIST_ROUTES = ["userActivity.assigned", "group.assigned.show"];

const AssignActionsCell = <template>
  <td class="assign-topic-buttons">
    <AssignedTopicListColumn @topic={{@topic}} />
  </td>
</template>;

export default {
  name: "assignment-list-dropdowns",

  initialize(container) {
    const router = container.lookup("service:router");

    withPluginApi("1.39.0", (api) => {
      api.registerValueTransformer(
        "topic-list-columns",
        ({ value: columns }) => {
          if (ASSIGN_LIST_ROUTES.includes(router.currentRouteName)) {
            columns.add("assign-actions", {
              item: AssignActionsCell,
              after: "activity",
            });
          }

          return columns;
        }
      );
      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value: classes }) => {
          if (ASSIGN_LIST_ROUTES.includes(router.currentRouteName)) {
            classes.push("assigned-list-item");
          }
          return classes;
        }
      );
    });
  },
};

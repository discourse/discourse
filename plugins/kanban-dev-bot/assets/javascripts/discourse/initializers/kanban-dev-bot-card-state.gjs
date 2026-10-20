import { apiInitializer } from "discourse/lib/api";
import KanbanDevBotCardState from "../components/kanban-dev-bot-card-state.gjs";

export default apiInitializer((api) => {
  api.renderInOutlet(
    "boards-card-status",
    <template>
      <KanbanDevBotCardState @board={{@board}} @card={{@card}} @mode="status" />
    </template>
  );
  api.renderInOutlet(
    "boards-card-actions",
    <template>
      <KanbanDevBotCardState
        @board={{@board}}
        @card={{@card}}
        @mode="actions"
        @onRefreshBoard={{@onRefreshBoard}}
      />
    </template>
  );
  api.renderInOutlet("boards-topic-card-detail-status", KanbanDevBotCardState);
});

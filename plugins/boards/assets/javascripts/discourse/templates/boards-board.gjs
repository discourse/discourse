import { array } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";
import BoardsBoardViewer from "../components/boards-board-viewer.gjs";

export default <template>
  {{bodyClass "discourse-boards-board"}}
  {{#each (array @controller.model) as |model|}}
    <BoardsBoardViewer
      @highlightCardId={{model.highlightCardId}}
      @model={{model}}
    />
  {{/each}}
</template>

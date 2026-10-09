import { array } from "@ember/helper";
import bodyClass from "discourse/helpers/body-class";
import BoardsBoardViewer from "../components/boards-board-viewer";

export default <template>
  {{bodyClass "discourse-boards-board"}}
  {{#each (array @controller.model) as |model|}}
    <BoardsBoardViewer
      @model={{model}}
      @openBoardSettings={{model.openBoardSettings}}
    />
  {{/each}}
</template>

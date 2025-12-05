import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import coldAgeClass from "discourse/helpers/cold-age-class";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import stripWhitespace from "discourse/helpers/strip-whitespace";

const ActivityCell = <template>
  {{#stripWhitespace}}
    <td
      title={{htmlSafe @topic.bumpedAtTitle}}
      class={{concatClass
        "activity num topic-list-data"
        (coldAgeClass @topic.createdAt startDate=@topic.bumpedAt class="")
      }}
      ...attributes
    >
      <a href={{@topic.lastPostUrl}} class="post-activity">
        <PluginOutlet
          @name="topic-list-before-relative-date"
          @outletArgs={{lazyHash topic=@topic}}
        />
        {{formatDate @topic.bumpedAt format="tiny" noTitle="true"}}
      </a>
    </td>
  {{/stripWhitespace}}
</template>;

export default ActivityCell;

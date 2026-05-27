import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import coldAgeClass from "discourse/helpers/cold-age-class";
import lazyHash from "discourse/helpers/lazy-hash";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";

const ActivityCell = <template>
  <td
    title={{trustHTML @topic.bumpedAtTitle}}
    class={{dConcatClass
      "activity num topic-list-data"
      (coldAgeClass @topic.createdAt startDate=@topic.bumpedAt class="")
    }}
    ...attributes
  >
    <a href={{@topic.lastPostUrl}} class="post-activity">
      {{~! no whitespace ~}}
      <PluginOutlet
        @name="topic-list-before-relative-date"
        @outletArgs={{lazyHash topic=@topic}}
      />
      {{~dFormatDate @topic.bumpedAt format="tiny" noTitle="true"~}}
    </a>
  </td>
</template>;

export default ActivityCell;

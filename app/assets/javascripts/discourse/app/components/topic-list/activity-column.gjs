import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import coldAgeClass from "discourse/helpers/cold-age-class";
import concatClass from "discourse/helpers/concat-class";
import element from "discourse/helpers/element";
import formatDate from "discourse/helpers/format-date";

export default class ActivityColumn extends Component {
  @service siteSettings;

  get wrapperElement() {
    return element(this.args.tagName ?? "td");
  }

  <template>
    <this.wrapperElement
      title={{htmlSafe @topic.bumpedAtTitle}}
      class={{concatClass
        "activity"
        (coldAgeClass @topic.createdAt startDate=@topic.bumpedAt class="")
      }}
      ...attributes
    >
      <a
        href={{@topic.lastPostUrl}}
        class="post-activity"
      >{{! no whitespace
        }}<PluginOutlet
          @name="topic-list-before-relative-date"
          @outletArgs={{hash topic=@topic}}
        />
        {{~formatDate @topic.bumpedAt format="tiny" noTitle="true"~}}
      </a>
    </this.wrapperElement>
  </template>
}

import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import coldAgeClass from "discourse/helpers/cold-age-class";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";

export default class ActivityColumn extends Component {
  @service siteSettings;

  get wrapperElement() {
    if (!this.args.tagName) {
      return <template><td ...attributes>{{yield}}</td></template>;
    } else if (this.args.tagName === "div") {
      return <template><div ...attributes>{{yield}}</div></template>;
    } else {
      throw new Error("Unsupported activity-column @tagName");
    }
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
        />
        {{~formatDate @topic.bumpedAt format="tiny" noTitle="true"~}}
      </a>
    </this.wrapperElement>
  </template>
}

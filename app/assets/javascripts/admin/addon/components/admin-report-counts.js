import { classNameBindings, tagName } from "@ember-decorators/component";
import { match } from "@ember/object/computed";
import Component from "@ember/component";

@tagName("tr")
@classNameBindings("reverseColors")
export default class AdminReportCounts extends Component {
  allTime = true;

  @match("report.type", /^(time_to_first_response|topics_with_no_response)$/)
  reverseColors;
}

import Component from "@glimmer/component";
import I18n from "I18n";

export default class Types extends Component {
  get filteredResultTypes() {
    if (this.args.topicResultsOnly) {
      return this.args.resultTypes.filter(
        (resultType) => resultType.type === "topic"
      );
    }
    return this.args.resultTypes;
  }
}

import Component from "@glimmer/component";

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

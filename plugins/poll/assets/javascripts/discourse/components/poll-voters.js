import Component from "@glimmer/component";
export default class PollVotersComponent extends Component {
  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }
}

import Component from "@glimmer/component";

export default class PollVotersComponent extends Component {
  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }

  get irvVoters() {
    let orderedVoters = [...this.args.voters];

    orderedVoters.forEach((voter) => {
      if (voter.rank === 0) {
        voter.rank = "Abstain";
      }
    });

    orderedVoters.sort((a, b) => {
      if (a.rank > b.rank) {
        return 1;
      } else if (a.rank === b.rank) {
        if (a.user.username < b.user.username) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return -1;
      }
    });

    // Group voters by rank
    const groupedObject = orderedVoters.reduce((groups, voter) => {
      const rank = voter.rank;
      if (!groups[rank]) {
        groups[rank] = [];
      }
      groups[rank].push(voter);
      return groups;
    }, {});

    const groupedVoters = Object.keys(groupedObject).map((rank) => ({
      rank,
      voters: groupedObject[rank],
    }));

    return groupedVoters;
  }
}

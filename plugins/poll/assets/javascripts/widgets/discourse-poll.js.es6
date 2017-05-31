import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode } from 'discourse/helpers/fa-icon-node';
import RawHtml from 'discourse/widgets/raw-html';
import { ajax } from 'discourse/lib/ajax';
import evenRound from "discourse/plugins/poll/lib/even-round";
import { avatarFor } from 'discourse/widgets/post';
import round from "discourse/lib/round";

function optionHtml(option) {
  return new RawHtml({ html: `<span>${option.html}</span>` });
}

function fetchVoters(payload) {
  return ajax("/polls/voters.json", {
    type: "get",
    data: payload
  }).catch(() => {
    bootbox.alert(I18n.t('poll.error_while_fetching_voters'));
  });
}

createWidget('discourse-poll-option', {
  tagName: 'li',

  buildAttributes(attrs) {
    return { 'data-poll-option-id': attrs.option.id };
  },

  html(attrs) {
    const result = [];

    const { option, vote } = attrs;
    const chosen = vote.indexOf(option.id) !== -1;

    if (attrs.isMultiple) {
      result.push(iconNode(chosen ? 'check-square-o' : 'square-o'));
    } else {
      result.push(iconNode(chosen ? 'dot-circle-o' : 'circle-o'));
    }
    result.push(' ');
    result.push(optionHtml(option));
    return result;
  },

  click(e) {
    if ($(e.target).closest("a").length === 0) {
      this.sendWidgetAction('toggleOption', this.attrs.option);
    }
  }
});

createWidget('discourse-poll-load-more', {
  tagName: 'div.poll-voters-toggle-expand',
  buildKey: attrs => `${attrs.id}-load-more`,

  defaultState() {
    return { loading: false };
  },

  html(attrs, state) {
    return state.loading ? h('div.spinner.small') : h('a', iconNode('chevron-down'));
  },

  click() {
    const { state } = this;
    if (state.loading) { return; }

    state.loading = true;
    return this.sendWidgetAction('loadMore').finally(() => state.loading = false);
  }

});

createWidget('discourse-poll-voters', {
  tagName: 'ul.poll-voters-list',
  buildKey: attrs => attrs.id(),

  defaultState() {
    return {
      loaded: 'new',
      pollVoters: [],
      offset: 1,
    };
  },

  fetchVoters() {
    const { attrs, state } = this;
    if (state.loaded === 'loading') { return; }

    state.loaded = 'loading';

    return fetchVoters({
      post_id: attrs.postId,
      poll_name: attrs.pollName,
      option_id: attrs.optionId,
      offset: state.offset
    }).then(result => {
      state.loaded = 'loaded';
      state.offset += 1;

      const pollResult = result[attrs.pollName];
      const newVoters = attrs.pollType === 'number' ? pollResult : pollResult[attrs.optionId];
      state.pollVoters = state.pollVoters.concat(newVoters);

      this.scheduleRerender();
    });
  },

  loadMore() {
    return this.fetchVoters();
  },

  html(attrs, state) {
    if (attrs.pollVoters && state.loaded === 'new') {
      state.pollVoters = attrs.pollVoters;
    }

    const contents = state.pollVoters.map(user => {
      return h('li', [avatarFor('tiny', {
        username: user.username,
        template: user.avatar_template
      }), ' ']);
    });

    if (state.pollVoters.length < attrs.totalVotes) {
      contents.push(this.attach('discourse-poll-load-more', { id: attrs.id() }));
    }

    return h('div.poll-voters', contents);
  }

});

createWidget('discourse-poll-standard-results', {
  tagName: 'ul.results',
  buildKey: attrs => `${attrs.id}-standard-results`,

  defaultState() {
    return {
      loaded: 'new'
    };
  },

  fetchVoters() {
    const { attrs, state } = this;

    if (state.loaded === 'new') {
      fetchVoters({
        post_id: attrs.post.id,
        poll_name: attrs.poll.get('name')
      }).then(result => {
        state.voters = result[attrs.poll.get('name')];
        state.loaded = 'loaded';
        this.scheduleRerender();
      });
    }
  },

  html(attrs, state) {
    const { poll } = attrs;
    const options = poll.get('options');

    if (options) {
      const voters = poll.get('voters');
      const isPublic = poll.get('public');

      const ordered = _.clone(options).sort((a, b) => {
        if (a.votes < b.votes) {
          return 1;
        } else if (a.votes === b.votes) {
          if (a.html < b.html) {
            return -1;
          } else {
            return 1;
          }
        } else {
          return -1;
        }
      });

      const percentages = voters === 0 ?
        Array(ordered.length).fill(0) :
        ordered.map(o => 100 * o.votes / voters);

      const rounded = attrs.isMultiple ? percentages.map(Math.floor) : evenRound(percentages);

      if (isPublic) this.fetchVoters();

      return ordered.map((option, idx) => {
        const contents = [];
        const per = rounded[idx].toString();
        const chosen = (attrs.vote || []).includes(option.id);

        contents.push(h('div.option',
                       h('p', [ h('span.percentage', `${per}%`), optionHtml(option) ])
                     ));

        contents.push(h('div.bar-back',
                       h('div.bar', { attributes: { style: `width:${per}%` }})
                     ));

        if (isPublic) {
          contents.push(this.attach('discourse-poll-voters', {
            id: () => `poll-voters-${option.id}`,
            postId: attrs.post.id,
            optionId: option.id,
            pollName: poll.get('name'),
            totalVotes: option.votes,
            pollVoters: (state.voters && state.voters[option.id]) || []
          }));
        }

        return h('li', { className: `${chosen ? 'chosen' : ''}` }, contents);
      });
    }
  }
});

createWidget('discourse-poll-number-results', {
  buildKey: attrs => `${attrs.id}-number-results`,

  defaultState() {
    return {
      loaded: 'new'
    };
  },

  fetchVoters() {
    const { attrs, state } = this;

    if (state.loaded === 'new') {

      fetchVoters({
        post_id: attrs.post.id,
        poll_name: attrs.poll.get('name')
      }).then(result => {
        state.voters = result[attrs.poll.get('name')];
        state.loaded = 'loaded';
        this.scheduleRerender();
      });
    }
  },

  html(attrs, state) {
    const { poll } = attrs;
    const isPublic = poll.get('public');

    const totalScore = poll.get('options').reduce((total, o) => {
      return total + parseInt(o.html, 10) * parseInt(o.votes, 10);
    }, 0);

    const voters = poll.voters;
    const average = voters === 0 ? 0 : round(totalScore / voters, -2);
    const averageRating = I18n.t("poll.average_rating", { average });
    const results = [h('div.poll-results-number-rating',
                       new RawHtml({ html: `<span>${averageRating}</span>` }))];

    if (isPublic) {
      this.fetchVoters();

      results.push(this.attach('discourse-poll-voters', {
        id: () => `poll-voters-${poll.get('name')}`,
        totalVotes: poll.get('voters'),
        pollVoters: state.voters || [],
        postId: attrs.post.id,
        pollName: poll.get('name'),
        pollType: poll.get('type')
      }));
    }

    return results;
  }
});

createWidget('discourse-poll-container', {
  tagName: 'div.poll-container',
  html(attrs) {
    const { poll } = attrs;

    if (attrs.showResults) {
      const type = poll.get('type') === 'number' ? 'number' : 'standard';
      return this.attach(`discourse-poll-${type}-results`, attrs);
    }

    const options = poll.get('options');
    if (options) {
      return h('ul', options.map(option => {
        return this.attach('discourse-poll-option', {
          option,
          isMultiple: attrs.isMultiple,
          vote: attrs.vote
        });
      }));
    }
  }
});

createWidget('discourse-poll-info', {
  tagName: 'div.poll-info',

  multipleHelpText(min, max, options) {
    if (max > 0) {
      if (min === max) {
        if (min > 1) {
          return I18n.t("poll.multiple.help.x_options", { count: min });
        }
      } else if (min > 1) {
        if (max < options) {
          return I18n.t("poll.multiple.help.between_min_and_max_options", { min, max });
        } else {
          return I18n.t("poll.multiple.help.at_least_min_options", { count: min });
        }
      } else if (max <= options) {
        return I18n.t("poll.multiple.help.up_to_max_options", { count: max });
      }
    }
  },

  html(attrs) {
    const { poll } = attrs;
    const count = poll.get('voters');
    const result = [h('p', [
                     h('span.info-number', count.toString()),
                     h('span.info-text', I18n.t('poll.voters', { count }))
                   ])];

    if (attrs.isMultiple) {
      if (attrs.showResults) {
        const totalVotes = poll.get('options').reduce((total, o) => {
          return total + parseInt(o.votes, 10);
        }, 0);

        result.push(h('p', [
                      h('span.info-number', totalVotes.toString()),
                      h('span.info-text', I18n.t("poll.total_votes", { count: totalVotes }))
                    ]));
      } else {
        const help = this.multipleHelpText(attrs.min, attrs.max, poll.get('options.length'));
        if (help) {
          result.push(new RawHtml({ html: `<span>${help}</span>` }));
        }
      }
    }

    if (!attrs.showResults && attrs.poll.get('public')) {
      result.push(h('p', I18n.t('poll.public.title')));
    }

    return result;
  }
});

createWidget('discourse-poll-buttons', {
  tagName: 'div.poll-buttons',

  html(attrs) {
    const results = [];
    const { poll, post } = attrs;
    const topicArchived = post.get('topic.archived');
    const isClosed = poll.get('status') === 'closed';
    const hideResultsDisabled = isClosed || topicArchived;

    if (attrs.isMultiple && !hideResultsDisabled) {
      const castVotesDisabled = !attrs.canCastVotes;
      results.push(this.attach('button', {
        className: `btn cast-votes ${castVotesDisabled ? '' : 'btn-primary'}`,
        label: 'poll.cast-votes.label',
        title: 'poll.cast-votes.title',
        disabled: castVotesDisabled,
        action: 'castVotes'
      }));
      results.push(' ');
    }

    if (attrs.showResults) {
      results.push(this.attach('button', {
        className: 'btn toggle-results',
        label: 'poll.hide-results.label',
        title: 'poll.hide-results.title',
        icon: 'eye-slash',
        disabled: hideResultsDisabled,
        action: 'toggleResults'
      }));
    } else {
      results.push(this.attach('button', {
        className: 'btn toggle-results',
        label: 'poll.show-results.label',
        title: 'poll.show-results.title',
        icon: 'eye',
        disabled: poll.get('voters') === 0,
        action: 'toggleResults'
      }));
    }

    if (this.currentUser &&
        (this.currentUser.get("id") === post.get('user_id') ||
         this.currentUser.get("staff")) &&
        !topicArchived) {

      if (isClosed) {
        results.push(this.attach('button', {
          className: 'btn toggle-status',
          label: 'poll.open.label',
          title: 'poll.open.title',
          icon: 'unlock-alt',
          action: 'toggleStatus'
        }));
      } else {
        results.push(this.attach('button', {
          className: 'btn toggle-status btn-danger',
          label: 'poll.close.label',
          title: 'poll.close.title',
          icon: 'lock',
          action: 'toggleStatus'
        }));
      }
    }


    return results;
  }
});

export default createWidget('discourse-poll', {
  tagName: 'div.poll',
  buildKey: attrs => attrs.id,

  buildAttributes(attrs) {
    const { poll } = attrs;
    return {
      "data-poll-type":   poll.get('type'),
      "data-poll-name":   poll.get('name'),
      "data-poll-status": poll.get('status'),
      "data-poll-public": poll.get('public')
    };
  },

  defaultState(attrs) {
    const { poll, post } = attrs;
    return { loading: false,
             showResults: poll.get('isClosed') || post.get('topic.archived') };
  },

  html(attrs, state) {
    const { showResults } = state;
    const newAttrs = jQuery.extend({}, attrs, {
      showResults,
      canCastVotes: this.canCastVotes(),
      min: this.min(),
      max: this.max()
    });
    return h('div', [
      this.attach('discourse-poll-container', newAttrs),
      this.attach('discourse-poll-info', newAttrs),
      this.attach('discourse-poll-buttons', newAttrs)
    ]);
  },

  isClosed() {
    return this.attrs.poll.get('status') === "closed";
  },

  min() {
    let min = parseInt(this.attrs.poll.min, 10);
    if (isNaN(min) || min < 1) { min = 1; }
    return min;
  },

  max() {
    let max = parseInt(this.attrs.poll.max, 10);
    const numOptions = this.attrs.poll.options.length;
    if (isNaN(max) || max > numOptions) { max = numOptions; }
    return max;
  },

  canCastVotes() {
    const { state, attrs } = this;
    if (this.isClosed() || state.showResults || state.loading) {
      return false;
    }

    const selectedOptionCount = attrs.vote.length;
    if (attrs.isMultiple) {
      return selectedOptionCount >= this.min() && selectedOptionCount <= this.max();
    }
    return selectedOptionCount > 0;
  },

  toggleStatus() {
    const { state, attrs } = this;
    const { poll } = attrs;
    const isClosed = poll.get('status') === 'closed';

    bootbox.confirm(
      I18n.t(isClosed ? "poll.open.confirm" : "poll.close.confirm"),
      I18n.t("no_value"),
      I18n.t("yes_value"),
      confirmed => {
        if (confirmed) {
          state.loading = true;

          const status = isClosed ? "open" : "closed";
          ajax("/polls/toggle_status", {
            type: "PUT",
            data: {
              post_id: attrs.post.get('id'),
              poll_name: poll.get('name'),
              status,
            }
          }).then(() => {
            poll.set('status', status);
            this.scheduleRerender();
          }).catch(() => {
            bootbox.alert(I18n.t("poll.error_while_toggling_status"));
          }).finally(() => {
            state.loading = false;
          });
        }
      }
    );
  },

  toggleResults() {
    this.state.showResults = !this.state.showResults;
  },

  showLogin() {
    const appRoute = this.register.lookup('route:application');
    appRoute.send('showLogin');
  },

  toggleOption(option) {
    if (this.isClosed()) { return; }
    if (!this.currentUser) { this.showLogin(); }

    const { attrs } = this;
    const { vote } = attrs;

    const chosenIdx = vote.indexOf(option.id);
    if (!attrs.isMultiple) {
      vote.length = 0;
    }

    if (chosenIdx !== -1) {
      vote.splice(chosenIdx, 1);
    } else {
      vote.push(option.id);
    }

    if (!attrs.isMultiple) {
      return this.castVotes();
    }
  },

  castVotes() {
    if (!this.canCastVotes()) { return; }
    if (!this.currentUser) { return this.showLogin(); }

    const { attrs, state } = this;

    state.loading = true;

    return ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: attrs.post.id,
        poll_name: attrs.poll.name,
        options: attrs.vote
      }
    }).then(() => {
      state.showResults = true;
    }).catch(() => {
      bootbox.alert(I18n.t("poll.error_while_casting_votes"));
    }).finally(() => {
      state.loading = false;
    });
  }
});

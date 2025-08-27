import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import HorizontalScrollSyncWrapper from "discourse/components/horizontal-scroll-sync-wrapper";
import LoadMore from "discourse/components/load-more";
import TextField from "discourse/components/text-field";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import { i18n } from "discourse-i18n";
import EmailLog from "admin/models/email-log";

export default class EmailLogsList extends Component {
  @tracked loading = false;
  @tracked model = null;
  @tracked filterValues = {};
  @tracked initialized = false;
  @tracked loadMoreEnabled = false;

  sortWithAddressFilter = (addresses) => {
    if (!Array.isArray(addresses) || addresses.length === 0) {
      return [];
    }
    const targetEmail = this.filterValues.filterAddress;

    if (!targetEmail) {
      return addresses;
    }

    return addresses.sort((a, b) => {
      if (a.includes(targetEmail) && !b.includes(targetEmail)) {
        return -1;
      }
      if (!a.includes(targetEmail) && b.includes(targetEmail)) {
        return 1;
      }
      return 0;
    });
  };

  @action
  initializeComponent() {
    if (!this.initialized) {
      this.initialized = true;

      const initialValues = {};
      this.args.filters?.forEach((filter) => {
        initialValues[filter.property] = "";
      });
      this.filterValues = initialValues;

      this.loadLogs();
    }
  }

  get sourceModel() {
    return this.args.sourceModel || EmailLog;
  }

  get filterArgs() {
    const args = { status: this.args.status };

    this.args.filters?.forEach(({ property, name }) => {
      const value = this.filterValues[property];
      if (value) {
        args[name] = value;
      }
    });

    return args;
  }

  get ccAddressDisplayThreshold() {
    return this.args.ccAddressDisplayThreshold || 2;
  }

  get canLoadMore() {
    return (
      this.loadMoreEnabled &&
      this.model &&
      this.model.length > 0 &&
      !this.model.allLoaded &&
      !this.loading
    );
  }

  @action
  async loadLogs(loadMore = false) {
    if ((loadMore && this.loading) || (loadMore && this.model?.allLoaded)) {
      return;
    }

    this.loading = true;

    if (!loadMore && this.model) {
      this.model.set("allLoaded", false);
    }

    try {
      const logs = await this.sourceModel.findAll(
        this.filterArgs,
        loadMore ? this.model?.length : null
      );

      if (this.model && loadMore) {
        this.model.addObjects(logs);
        if (logs.length < 50) {
          this.model.set("allLoaded", true);
        }
      } else {
        this.model = logs;
        this.model.set("allLoaded", logs.length < 50);
        this.loadMoreEnabled = true;
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  updateFilter(filterName, event) {
    const filterConfig = this.args.filters.find((f) => f.name === filterName);
    if (filterConfig) {
      this.filterValues = {
        ...this.filterValues,
        [filterConfig.property]: event.target.value,
      };
      this.loadMoreEnabled = false;
      discourseDebounce(this, this.loadLogs, INPUT_DELAY);
    }
  }

  @action
  loadMore() {
    this.loadLogs(true);
  }

  @action
  handleShowIncomingEmail(id, event) {
    event?.preventDefault();
    if (this.args.onShowEmail) {
      this.args.onShowEmail(id);
    }
  }

  <template>
    <LoadMore
      @action={{this.loadMore}}
      @enabled={{this.canLoadMore}}
      @rootMargin="0px 0px 250px 0px"
      {{didInsert this.initializeComponent}}
    >
      <HorizontalScrollSyncWrapper>
        <table class="table email-list">
          <thead>
            <tr>
              <th>{{i18n "admin.email.sent_at"}}</th>
              {{#each @headers as |header|}}
                <th colspan={{header.colspan}}>{{i18n header.key}}</th>
              {{/each}}
            </tr>
          </thead>
          <tbody>
            <tr class="filters">
              <td><span class="sr-only">
                  {{i18n "admin.email.logs.filters.title"}}</span>
              </td>
              {{#each @filters as |filter|}}
                <td>
                  <TextField
                    @value={{get this.filterValues filter.property}}
                    @placeholderKey={{filter.placeholder}}
                    {{on "input" (fn this.updateFilter filter.name)}}
                  />
                </td>
              {{/each}}
              {{#each @extraFilterCells as |cell|}}
                <td>{{#if cell.content}}{{cell.content}}{{/if}}</td>
              {{/each}}
            </tr>

            {{#each this.model as |emailLog|}}
              {{yield
                emailLog
                this.ccAddressDisplayThreshold
                this.sortWithAddressFilter
                this.handleShowIncomingEmail
              }}
            {{else}}
              {{#unless this.loading}}
                <tr>
                  <td colspan="6">{{i18n "admin.email.logs.none"}}</td>
                </tr>
              {{/unless}}
            {{/each}}
          </tbody>
        </table>
      </HorizontalScrollSyncWrapper>
    </LoadMore>

    <ConditionalLoadingSpinner @condition={{this.loading}} />
  </template>
}

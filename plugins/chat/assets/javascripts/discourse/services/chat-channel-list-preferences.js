import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  CHAT_CHANNEL_LIST_FILTERS,
  CHAT_CHANNEL_LIST_SORTS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";

const VALID_FILTERS = new Set(Object.values(CHAT_CHANNEL_LIST_FILTERS));
const VALID_SORTS = new Set(Object.values(CHAT_CHANNEL_LIST_SORTS));

const SECTIONS = {
  channels: {
    filter: {
      field: "chat_channel_list_filter",
      value: "channelsFilter",
      saving: "isSavingChannelsFilter",
    },
    sort: {
      field: "chat_channel_list_sort",
      value: "channelsSort",
      saving: "isSavingChannelsSort",
    },
  },
  starred: {
    filter: {
      field: "chat_channel_list_filter_starred",
      value: "starredFilter",
      saving: "isSavingStarredFilter",
    },
    sort: {
      field: "chat_channel_list_sort_starred",
      value: "starredSort",
      saving: "isSavingStarredSort",
    },
  },
  dms: {
    filter: {
      field: "chat_channel_list_filter_dms",
      value: "dmsFilter",
      saving: "isSavingDmsFilter",
    },
    sort: {
      field: "chat_channel_list_sort_dms",
      value: "dmsSort",
      saving: "isSavingDmsSort",
    },
  },
};

export default class ChatChannelListPreferences extends Service {
  @service currentUser;

  @tracked channelsFilter;
  @tracked starredFilter;
  @tracked dmsFilter;
  @tracked channelsSort;
  @tracked starredSort;
  @tracked dmsSort;
  @tracked isSavingChannelsFilter = false;
  @tracked isSavingStarredFilter = false;
  @tracked isSavingDmsFilter = false;
  @tracked isSavingChannelsSort = false;
  @tracked isSavingStarredSort = false;
  @tracked isSavingDmsSort = false;
  @tracked _bypassedFilters = {};

  constructor() {
    super(...arguments);

    const userOption = this.currentUser?.user_option;
    this.channelsFilter = this.#validFilter(
      userOption?.chat_channel_list_filter
    );
    this.starredFilter = this.#validFilter(
      userOption?.chat_channel_list_filter_starred
    );
    this.dmsFilter = this.#validFilter(
      userOption?.chat_channel_list_filter_dms
    );
    this.channelsSort = this.#validSort(userOption?.chat_channel_list_sort);
    this.starredSort = this.#validSort(
      userOption?.chat_channel_list_sort_starred
    );
    this.dmsSort = this.#validSort(userOption?.chat_channel_list_sort_dms);
  }

  /** The filter preference for a section: `"channels"`, `"starred"`, or `"dms"`. */
  filterFor(section) {
    return (
      this[this.#section(section).filter.value] ?? CHAT_CHANNEL_LIST_FILTERS.ALL
    );
  }

  effectiveFilterFor(section) {
    return this.isFilterBypassedFor(section)
      ? CHAT_CHANNEL_LIST_FILTERS.ALL
      : this.filterFor(section);
  }

  isFilterBypassedFor(section) {
    return this._bypassedFilters[section] ?? false;
  }

  showAllChannels(section) {
    if (SECTIONS[section] && !this.isSavingFilterFor(section)) {
      this._bypassedFilters = { ...this._bypassedFilters, [section]: true };
    }
  }

  applyFilter(section) {
    this._bypassedFilters = { ...this._bypassedFilters, [section]: false };
  }

  toggleFilter(section) {
    if (this.isFilterBypassedFor(section)) {
      this.applyFilter(section);
    } else {
      this.showAllChannels(section);
    }
  }

  isDefaultFilterFor(section) {
    return this.filterFor(section) === CHAT_CHANNEL_LIST_FILTERS.ALL;
  }

  isSavingFilterFor(section) {
    return this[this.#section(section).filter.saving];
  }

  /** The sort preference for a section: `"channels"`, `"starred"`, or `"dms"`. */
  sortFor(section) {
    return (
      this[this.#section(section).sort.value] ??
      CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL
    );
  }

  isSavingSortFor(section) {
    return this[this.#section(section).sort.saving];
  }

  async setFilter(section, filter) {
    if (!SECTIONS[section]) {
      return false;
    }
    if (!VALID_FILTERS.has(filter)) {
      return false;
    }

    if (!this.currentUser || this.isSavingFilterFor(section)) {
      return false;
    }

    const bypassed = this.isFilterBypassedFor(section);
    this.applyFilter(section);
    const { field, value, saving } = SECTIONS[section].filter;
    const saved = await this.#save(field, value, saving, filter);
    if (!saved && bypassed) {
      this.showAllChannels(section);
    }
    return saved;
  }

  async setSort(section, sort) {
    if (!SECTIONS[section]) {
      return false;
    }
    if (!VALID_SORTS.has(sort)) {
      return false;
    }

    const { field, value, saving } = SECTIONS[section].sort;
    return await this.#save(field, value, saving, sort);
  }

  #section(section) {
    return SECTIONS[section] ?? SECTIONS.channels;
  }

  #validFilter(value) {
    return VALID_FILTERS.has(value) ? value : CHAT_CHANNEL_LIST_FILTERS.ALL;
  }

  #validSort(value) {
    return VALID_SORTS.has(value)
      ? value
      : CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL;
  }

  async #save(fieldName, propertyName, savingPropertyName, value) {
    if (!this.currentUser || this[savingPropertyName]) {
      return false;
    }

    if (this[propertyName] === value) {
      return true;
    }

    const previousValue = this[propertyName];
    this[propertyName] = value;
    this.currentUser.set(`user_option.${fieldName}`, value);
    this[savingPropertyName] = true;

    try {
      await this.currentUser.save([fieldName]);
      return true;
    } catch (error) {
      this[propertyName] = previousValue;
      this.currentUser.set(`user_option.${fieldName}`, previousValue);
      popupAjaxError(error);
      return false;
    } finally {
      this[savingPropertyName] = false;
    }
  }
}

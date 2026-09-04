import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  CHAT_CHANNEL_LIST_FILTERS,
  CHAT_CHANNEL_LIST_SORTS,
} from "discourse/plugins/chat/discourse/lib/chat-constants";

const FILTER_FIELD = "chat_channel_list_filter";
const SORT_FIELD = "chat_channel_list_sort";
const VALID_FILTERS = new Set(Object.values(CHAT_CHANNEL_LIST_FILTERS));
const VALID_SORTS = new Set(Object.values(CHAT_CHANNEL_LIST_SORTS));

export default class ChatChannelListPreferences extends Service {
  @service currentUser;

  @tracked filter;
  @tracked isSavingFilter = false;
  @tracked isSavingSort = false;
  @tracked sort;

  constructor() {
    super(...arguments);

    const filter = this.currentUser?.user_option?.[FILTER_FIELD];
    const sort = this.currentUser?.user_option?.[SORT_FIELD];
    this.filter = VALID_FILTERS.has(filter)
      ? filter
      : CHAT_CHANNEL_LIST_FILTERS.ALL;
    this.sort = VALID_SORTS.has(sort)
      ? sort
      : CHAT_CHANNEL_LIST_SORTS.ALPHABETICAL;
  }

  get isDefaultFilter() {
    return this.filter === CHAT_CHANNEL_LIST_FILTERS.ALL;
  }

  get isSaving() {
    return this.isSavingFilter || this.isSavingSort;
  }

  async setFilter(filter) {
    if (!VALID_FILTERS.has(filter)) {
      return false;
    }

    return await this.#save(FILTER_FIELD, "filter", "isSavingFilter", filter);
  }

  async setSort(sort) {
    if (!VALID_SORTS.has(sort)) {
      return false;
    }

    return await this.#save(SORT_FIELD, "sort", "isSavingSort", sort);
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

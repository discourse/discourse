import Controller from '@ember/controller';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { ajax } from 'discourse/lib/ajax';
import I18n from 'I18n';

export default class TangyzenController extends Controller {
  @tracked items = [];
  @tracked meta = {};
  @tracked currentType = 'deals';
  @tracked isLoading = false;
  @tracked isLoadingMore = false;
  @tracked selectedCategory = null;
  @tracked selectedSort = 'trending';
  
  get contentTypes() {
    return [
      { id: 'deals', icon: '💰', label: I18n.t('tangyzen.deals') },
      { id: 'music', icon: '🎵', label: I18n.t('tangyzen.music') },
      { id: 'movies', icon: '🍿', label: I18n.t('tangyzen.movies') },
      { id: 'reviews', icon: '⚖️', label: I18n.t('tangyzen.reviews') },
      { id: 'arts', icon: '📸', label: I18n.t('tangyzen.arts') },
      { id: 'blogs', icon: '✍️', label: I18n.t('tangyzen.blogs') }
    ];
  }
  
  get sortOptions() {
    return [
      { id: 'trending', label: I18n.t('tangyzen.sort.trending') },
      { id: 'latest', label: I18n.t('tangyzen.sort.latest') },
      { id: 'popular', label: I18n.t('tangyzen.sort.popular') },
      { id: 'highest_discount', label: I18n.t('tangyzen.sort.highest_discount') },
      { id: 'ending_soon', label: I18n.t('tangyzen.sort.ending_soon') }
    ];
  }
  
  get currentPage() {
    return this.meta.page || 1;
  }
  
  get totalPages() {
    return Math.ceil((this.meta.total || 0) / (this.meta.limit || 20));
  }
  
  get hasMoreItems() {
    return this.currentPage < this.totalPages;
  }
  
  @action
  selectType(type) {
    this.currentType = type;
    this.isLoading = true;
    this.transitionToRoute({ queryParams: { type } });
  }
  
  @action
  selectSort(sort) {
    this.selectedSort = sort;
    this.transitionToRoute({ queryParams: { sort } });
  }
  
  @action
  selectCategory(categoryId) {
    this.selectedCategory = categoryId;
    this.transitionToRoute({ queryParams: { category: categoryId } });
  }
  
  @action
  async likeItem(type, id) {
    try {
      await ajax(`/tangyzen/${type}/${id}/like`, { method: 'POST' });
      
      const item = this.items.find(item => item.id === id);
      if (item) {
        item.user_liked = true;
        item.likes_count++;
      }
    } catch (error) {
      console.error('Failed to like:', error);
      this.appEvents.trigger('flash-message', {
        type: 'error',
        message: I18n.t('tangyzen.errors.like_failed')
      });
    }
  }
  
  @action
  async unlikeItem(type, id) {
    try {
      await ajax(`/tangyzen/${type}/${id}/unlike`, { method: 'POST' });
      
      const item = this.items.find(item => item.id === id);
      if (item) {
        item.user_liked = false;
        item.likes_count--;
      }
    } catch (error) {
      console.error('Failed to unlike:', error);
      this.appEvents.trigger('flash-message', {
        type: 'error',
        message: I18n.t('tangyzen.errors.unlike_failed')
      });
    }
  }
  
  @action
  async saveItem(type, id) {
    try {
      await ajax(`/tangyzen/${type}/${id}/save`, { method: 'POST' });
      
      const item = this.items.find(item => item.id === id);
      if (item) {
        item.user_saved = true;
      }
      
      this.appEvents.trigger('flash-message', {
        type: 'success',
        message: I18n.t('tangyzen.saved')
      });
    } catch (error) {
      console.error('Failed to save:', error);
      this.appEvents.trigger('flash-message', {
        type: 'error',
        message: I18n.t('tangyzen.errors.save_failed')
      });
    }
  }
  
  @action
  async unsaveItem(type, id) {
    try {
      await ajax(`/tangyzen/${type}/${id}/unsave`, { method: 'POST' });
      
      const item = this.items.find(item => item.id === id);
      if (item) {
        item.user_saved = false;
      }
      
      this.appEvents.trigger('flash-message', {
        type: 'success',
        message: I18n.t('tangyzen.unsaved')
      });
    } catch (error) {
      console.error('Failed to unsave:', error);
      this.appEvents.trigger('flash-message', {
        type: 'error',
        message: I18n.t('tangyzen.errors.unsave_failed')
      });
    }
  }
  
  @action
  loadMore() {
    if (this.isLoadingMore || !this.hasMoreItems) return;
    
    this.isLoadingMore = true;
    this.send('loadMore');
  }
  
  @action
  refreshContent() {
    this.isLoading = true;
    this.send('refresh');
  }
}

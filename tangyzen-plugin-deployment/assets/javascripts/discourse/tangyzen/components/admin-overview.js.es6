import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { ajax } from 'discourse/lib/ajax';
import { TangyzenAdmin } from '../admin';

export default class AdminOverview extends Component {
  @tracked stats = null;
  @tracked recentActivity = [];
  @tracked trendingContent = [];
  @tracked loading = false;
  @tracked error = null;
  
  @tracked syncInProgress = false;
  
  constructor() {
    super(...arguments);
    this.loadData();
  }
  
  async loadData() {
    this.loading = true;
    this.error = null;
    
    try {
      const response = await TangyzenAdmin.getOverview();
      this.stats = response.stats;
      this.recentActivity = response.recent_activity || [];
      this.trendingContent = response.trending_content || [];
    } catch (err) {
      this.error = err;
      console.error('Failed to load admin data:', err);
    } finally {
      this.loading = false;
    }
  }
  
  @action
  async refreshData() {
    await this.loadData();
  }
  
  @action
  async syncWeb3Data() {
    if (this.syncInProgress) return;
    
    this.syncInProgress = true;
    
    try {
      await TangyzenAdmin.syncWeb3Data([], true);
      this.appEvents.trigger('flash-message', {
        message: 'Web3 sync started successfully',
        message_type: 'success'
      });
    } catch (err) {
      this.appEvents.trigger('flash-message', {
        message: 'Failed to start Web3 sync',
        message_type: 'error'
      });
      console.error('Web3 sync error:', err);
    } finally {
      this.syncInProgress = false;
    }
  }
  
  get statCards() {
    if (!this.stats) return [];
    
    return [
      {
        label: 'Deals',
        value: this.stats.total_deals,
        icon: 'tag',
        color: '#3b82f6'
      },
      {
        label: 'Gaming',
        value: this.stats.total_gaming,
        icon: 'gamepad',
        color: '#ec4899'
      },
      {
        label: 'Music',
        value: this.stats.total_music,
        icon: 'music',
        color: '#8b5cf6'
      },
      {
        label: 'Movies',
        value: this.stats.total_movies,
        icon: 'film',
        color: '#f59e0b'
      },
      {
        label: 'Reviews',
        value: this.stats.total_reviews,
        icon: 'star',
        color: '#10b981'
      },
      {
        label: 'Art',
        value: this.stats.total_art,
        icon: 'image',
        color: '#06b6d4'
      },
      {
        label: 'Blogs',
        value: this.stats.total_blogs,
        icon: 'pen',
        color: '#ef4444'
      },
      {
        label: 'Users',
        value: this.stats.total_users,
        icon: 'users',
        color: '#6366f1'
      }
    ];
  }
  
  get totalViews() {
    return this.formatNumber(this.stats?.total_views || 0);
  }
  
  get totalLikes() {
    return this.formatNumber(this.stats?.total_likes || 0);
  }
  
  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }
}

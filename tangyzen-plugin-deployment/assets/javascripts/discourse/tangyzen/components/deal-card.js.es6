import { withPluginApi } from 'discourse/lib/plugin-api';
import DiscourseURL from 'discourse/lib/url';
import { ajax } from 'discourse/lib/ajax';

export default Ember.Component.extend({
  classNames: ['tangyzen-deal-card'],
  classNameBindings: ['isFeatured:tangyzen-deal-card-featured', 'isExpired:tangyzen-deal-card-expired'],
  
  deal: null,
  isFeatured: Ember.computed.readOnly('deal.is_featured'),
  isExpired: Ember.computed('deal.expiry_date', function() {
    if (!this.get('deal.expiry_date')) return false;
    return new Date(this.get('deal.expiry_date')) < new Date();
  }),
  
  timeRemaining: Ember.computed('deal.expiry_date', function() {
    if (!this.get('deal.expiry_date')) return null;
    const expiry = new Date(this.get('deal.expiry_date'));
    const now = new Date();
    const diff = expiry - now;
    
    if (diff <= 0) return 'expired';
    
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (days > 0) return I18n.t('tangyzen.deals.time_remaining.days', { count: days });
    if (hours > 0) return I18n.t('tangyzen.deals.time_remaining.hours', { count: hours });
    return I18n.t('tangyzen.deals.time_remaining.expires_soon');
  }),
  
  discountPercentage: Ember.computed('deal.discount_percentage', function() {
    const discount = this.get('deal.discount_percentage');
    return discount ? `${Math.round(discount)}% OFF` : null;
  }),
  
  discountAmount: Ember.computed('deal.original_price', 'deal.current_price', function() {
    const original = parseFloat(this.get('deal.original_price'));
    const current = parseFloat(this.get('deal.current_price'));
    if (!original || !current) return null;
    const amount = original - current;
    return I18n.t('tangyzen.deals.save_amount', { amount: amount.toFixed(2) });
  }),
  
  isLiked: false,
  isSaved: false,
  likesCount: Ember.computed.readOnly('deal.likes_count'),
  commentsCount: Ember.computed.readOnly('deal.comments_count'),
  
  init() {
    this._super(...arguments);
    this.setProperties({
      isLiked: this.get('deal.user_liked') || false,
      isSaved: this.get('deal.user_saved') || false,
      likesCount: this.get('deal.likes_count') || 0
    });
  },
  
  actions: {
    likeDeal() {
      const dealId = this.get('deal.id');
      
      ajax(`/tangyzen/deals/${dealId}/like`, { method: 'POST' })
        .then((result) => {
          this.setProperties({
            isLiked: true,
            likesCount: result.likes_count
          });
          this.appEvents.trigger('deal:liked', { dealId });
        })
        .catch((error) => {
          this.flash(error.error || I18n.t('tangyzen.errors.like_failed'), 'error');
        });
    },
    
    unlikeDeal() {
      const dealId = this.get('deal.id');
      
      ajax(`/tangyzen/deals/${dealId}/unlike`, { method: 'POST' })
        .then((result) => {
          this.setProperties({
            isLiked: false,
            likesCount: result.likes_count
          });
          this.appEvents.trigger('deal:unliked', { dealId });
        })
        .catch((error) => {
          this.flash(error.error || I18n.t('tangyzen.errors.unlike_failed'), 'error');
        });
    },
    
    saveDeal() {
      const dealId = this.get('deal.id');
      
      ajax(`/tangyzen/deals/${dealId}/save`, { method: 'POST' })
        .then(() => {
          this.set('isSaved', true);
          this.flash(I18n.t('tangyzen.deals.saved'), 'success');
          this.appEvents.trigger('deal:saved', { dealId });
        })
        .catch((error) => {
          this.flash(error.error || I18n.t('tangyzen.errors.save_failed'), 'error');
        });
    },
    
    unsaveDeal() {
      const dealId = this.get('deal.id');
      
      ajax(`/tangyzen/deals/${dealId}/unsave`, { method: 'POST' })
        .then(() => {
          this.set('isSaved', false);
          this.flash(I18n.t('tangyzen.deals.unsaved'), 'success');
          this.appEvents.trigger('deal:unsaved', { dealId });
        })
        .catch((error) => {
          this.flash(error.error || I18n.t('tangyzen.errors.unsave_failed'), 'error');
        });
    },
    
    visitDeal() {
      const dealId = this.get('deal.id');
      const dealUrl = this.get('deal.deal_url');
      
      // Track click
      ajax(`/tangyzen/deals/${dealId}/click`, { method: 'POST' })
        .catch((error) => {
          console.error('Failed to track click:', error);
        });
      
      // Open deal URL in new tab
      window.open(dealUrl, '_blank', 'noopener,noreferrer');
    },
    
    copyCoupon() {
      const couponCode = this.get('deal.coupon_code');
      
      if (couponCode && navigator.clipboard) {
        navigator.clipboard.writeText(couponCode)
          .then(() => {
            this.flash(I18n.t('tangyzen.deals.coupon_copied', { code: couponCode }), 'success');
          })
          .catch(() => {
            this.flash(I18n.t('tangyzen.errors.copy_failed'), 'error');
          });
      }
    },
    
    viewTopic() {
      const topicId = this.get('deal.topic_id');
      if (topicId) {
        DiscourseURL.routeTo(`/t/${topicId}`);
      }
    }
  }
});

// Register component
withPluginApi('0.1', api => {
  api.registerConnectorClass('topic-list-item', 'tangyzen-deal-card', {
    actions: {
      showDealCard: function() {
        this.sendAction('showDealCard');
      }
    }
  });
});

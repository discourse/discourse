import { withPluginApi } from 'discourse/lib/plugin-api';
import { ajax } from 'discourse/lib/ajax';

export default {
  name: 'tangyzen-home',
  initialize(container) {
    withPluginApi('0.1', api => {
      const currentUser = api.getCurrentUser();
      
      // Add custom navigation
      if (api.registerCustomNavigationItem) {
        api.registerCustomNavigationItem('tangyzen-deals', 'deals', {
          customFilter: (tag) => tag === 'deal',
          noSubcategories: false,
          after: 'new',
          forceFilter: true
        });
      }
      
      // Add "Submit Deal" button
      api.registerConnectorClass('above-main-container', 'tangyzen-submit-deal', {
        actions: {
          openSubmitDealModal: function() {
            api.container.lookup('service:modal').show('submit-deal');
          }
        }
      });
      
      // Custom homepage
      api.decorateWidget('home-logo:after', helper => {
        if (!currentUser) return;
        
        const router = container.lookup('service:router');
        
        return helper.rawHtml(`
          <div class="tangyzen-home-actions">
            <button class="btn btn-primary" id="submit-deal-btn">
              <span class="icon">💰</span> ${I18n.t('tangyzen.submit_deal')}
            </button>
            <button class="btn btn-secondary" id="submit-music-btn">
              <span class="icon">🎵</span> ${I18n.t('tangyzen.submit_music')}
            </button>
          </div>
        `);
      });
      
      // Load featured content
      api.decorateWidget('home-logo:after', helper => {
        return helper.rawHtml(`
          <div class="tangyzen-featured-section">
            <h2 class="tangyzen-section-title">⭐ ${I18n.t('tangyzen.featured_deals')}</h2>
            <div class="tangyzen-deals-grid" id="featured-deals-grid">
              <div class="tangyzen-loading">
                ${I18n.t('tangyzen.loading')}
              </div>
            </div>
          </div>
          
          <div class="tangyzen-trending-section">
            <h2 class="tangyzen-section-title">🔥 ${I18n.t('tangyzen.trending_content')}</h2>
            <div class="tangyzen-tabs">
              <button class="tangyzen-tab active" data-type="deals">${I18n.t('tangyzen.deals')}</button>
              <button class="tangyzen-tab" data-type="music">${I18n.t('tangyzen.music')}</button>
              <button class="tangyzen-tab" data-type="movies">${I18n.t('tangyzen.movies')}</button>
              <button class="tangyzen-tab" data-type="reviews">${I18n.t('tangyzen.reviews')}</button>
              <button class="tangyzen-tab" data-type="arts">${I18n.t('tangyzen.arts')}</button>
              <button class="tangyzen-tab" data-type="blogs">${I18n.t('tangyzen.blogs')}</button>
            </div>
            <div class="tangyzen-content-grid" id="trending-content-grid">
              <div class="tangyzen-loading">
                ${I18n.t('tangyzen.loading')}
              </div>
            </div>
          </div>
        `);
      });
      
      // Initialize content loading
      api.onPageChange((url, title) => {
        if (url === '' || url === '/') {
          this.loadFeaturedDeals();
          this.loadTrendingContent('deals');
        }
      });
      
      // Add CSS styles
      api.decorateWidget('home-logo:after', helper => {
        return helper.rawHtml(`
          <style>
            .tangyzen-home-actions {
              display: flex;
              gap: 12px;
              justify-content: center;
              margin: 20px 0;
              padding: 16px;
              background: var(--secondary);
              border-radius: 12px;
            }
            
            .tangyzen-home-actions .btn {
              display: flex;
              align-items: center;
              gap: 8px;
              padding: 12px 24px;
              border-radius: 8px;
              font-weight: 600;
              font-size: 14px;
              transition: all 0.2s ease;
            }
            
            .tangyzen-home-actions .btn:hover {
              transform: translateY(-2px);
              box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
            }
            
            .tangyzen-featured-section,
            .tangyzen-trending-section {
              margin: 40px 0;
            }
            
            .tangyzen-section-title {
              font-size: 24px;
              font-weight: 700;
              margin-bottom: 20px;
              color: var(--primary);
            }
            
            .tangyzen-tabs {
              display: flex;
              gap: 8px;
              margin-bottom: 20px;
              flex-wrap: wrap;
            }
            
            .tangyzen-tab {
              padding: 10px 20px;
              border-radius: 20px;
              border: 2px solid var(--primary-low);
              background: transparent;
              color: var(--primary-medium);
              font-weight: 600;
              font-size: 14px;
              cursor: pointer;
              transition: all 0.2s ease;
            }
            
            .tangyzen-tab:hover {
              border-color: var(--primary);
              color: var(--primary);
            }
            
            .tangyzen-tab.active {
              background: var(--primary);
              border-color: var(--primary);
              color: white;
            }
            
            .tangyzen-deals-grid,
            .tangyzen-content-grid {
              display: grid;
              grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
              gap: 20px;
            }
            
            .tangyzen-loading {
              text-align: center;
              padding: 40px;
              color: var(--primary-medium);
              font-size: 14px;
            }
          </style>
        `);
      });
    });
  },
  
  loadFeaturedDeals() {
    return ajax('/tangyzen/deals/featured')
      .then(result => {
        const grid = document.getElementById('featured-deals-grid');
        if (!grid) return;
        
        grid.innerHTML = result.deals.map(deal => `
          <div class="tangyzen-deal-card ${deal.is_featured ? 'tangyzen-deal-card-featured' : ''}">
            <div class="tangyzen-deal-card-image">
              <img src="${deal.image_url || '/images/default-deal.png'}" alt="${deal.title}">
              <div class="tangyzen-deal-card-badge">${Math.round(deal.discount_percentage)}% OFF</div>
            </div>
            <div class="tangyzen-deal-card-body">
              <h3 class="tangyzen-deal-card-title">
                <a href="/t/${deal.topic_id}">${deal.title}</a>
              </h3>
              <div class="tangyzen-deal-card-prices">
                <span class="tangyzen-deal-card-price-current">$${deal.current_price}</span>
                <span class="tangyzen-deal-card-price-original">$${deal.original_price}</span>
              </div>
              <div class="tangyzen-deal-card-store">
                <span>${deal.store_name}</span>
              </div>
            </div>
          </div>
        `).join('');
      })
      .catch(error => {
        console.error('Failed to load featured deals:', error);
      });
  },
  
  loadTrendingContent(type) {
    return ajax(`/tangyzen/${type}/trending`)
      .then(result => {
        const grid = document.getElementById('trending-content-grid');
        if (!grid) return;
        
        const items = result[`${type.slice(0, -1) === 'deals' ? 'deals' : type.slice(0, -1)}`] || result.items || [];
        
        grid.innerHTML = items.map(item => `
          <div class="tangyzen-content-card tangyzen-${type}-card">
            <div class="tangyzen-card-image">
              <img src="${item.image_url || item.cover_image || '/images/default.png'}" alt="${item.title}">
            </div>
            <div class="tangyzen-card-body">
              <h3 class="tangyzen-card-title">
                <a href="/t/${item.topic_id}">${item.title}</a>
              </h3>
              <div class="tangyzen-card-meta">
                <span class="tangyzen-card-likes">${item.likes_count} likes</span>
                <span class="tangyzen-card-comments">${item.comments_count} comments</span>
              </div>
            </div>
          </div>
        `).join('');
      })
      .catch(error => {
        console.error(`Failed to load trending ${type}:`, error);
      });
  }
};

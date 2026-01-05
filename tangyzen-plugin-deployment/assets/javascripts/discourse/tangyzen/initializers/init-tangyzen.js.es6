import { withPluginApi } from 'discourse/lib/plugin-api';
import { inject as service } from '@ember/service';

export default {
  name: 'init-tangyzen',
  
  initialize(container) {
    withPluginApi('0.1', api => {
      const currentUser = api.getCurrentUser();
      
      // Register TangyZen service
      api.registerService('tangyzen', {
        api,
        
        // Get user preferences
        getUserPreferences() {
          return ajax('/u/tangyzen/preferences.json');
        },
        
        // Update user preferences
        updateUserPreferences(preferences) {
          return ajax('/u/tangyzen/preferences.json', {
            type: 'PUT',
            data: { preferences }
          });
        },
        
        // Get deals by category
        getDealsByCategory(categoryId, options = {}) {
          return ajax('/tangyzen/deals.json', {
            data: {
              category: categoryId,
              ...options
            }
          });
        },
        
        // Get featured deals
        getFeaturedDeals() {
          return ajax('/tangyzen/deals/featured.json');
        },
        
        // Get trending content by type
        getTrendingContent(type) {
          return ajax(`/tangyzen/${type}/trending.json`);
        },
        
        // Submit new content
        submitContent(type, data) {
          return ajax(`/tangyzen/${type}`, {
            type: 'POST',
            data
          });
        },
        
        // Like content
        likeContent(type, id) {
          return ajax(`/tangyzen/${type}/${id}/like`, {
            type: 'POST'
          });
        },
        
        // Save content
        saveContent(type, id) {
          return ajax(`/tangyzen/${type}/${id}/save`, {
            type: 'POST'
          });
        }
      });
      
      // Add composer button for submitting deals
      api.addToolbarPopupMenuOptionsCallback(() => {
        return {
          action: 'submitTangyzenDeal',
          icon: 'tag',
          label: 'tangyzen.submit_deal_button',
          group: 'insertions'
        };
      });
      
      // Handle "Submit Deal" action
      api.onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: 'submit-deal',
          group: 'extras',
          icon: 'tag',
          title: 'tangyzen.submit_deal_button',
          perform: () => {
            api.container.lookup('service:modal').show('submit-deal');
          }
        });
      });
      
      // Add custom topic list badge for TangyZen content
      api.addTopicListPostProcessedCallback((topic, params) => {
        if (topic.tangyzen_content_type) {
          const contentType = topic.tangyzen_content_type;
          const badgeHtml = `
            <span class="tangyzen-topic-badge tangyzen-${contentType}-badge">
              ${this.getContentTypeIcon(contentType)}
            </span>
          `;
          topic.content += badgeHtml;
        }
      });
      
      // Add content type icon
      api.addPostTransformCallback(post => => {
        if (post.topic && post.topic.tangyzen_content_type) {
          const contentType = post.topic.tangyzen_content_type;
          const icon = this.getContentTypeIcon(contentType);
          post.content = `<div class="tangyzen-post-header">${icon} ${this.getContentTypeLabel(contentType)}</div>` + post.content;
        }
      });
      
      // Add custom route for TangyZen home
      api.addDiscoveryPage('tangyzen', {
        route: 'tangyzen',
        title: 'tangyzen.title',
        filter: 'tangyzen'
      });
      
      // Add widget for TangyZen navigation
      api.addHeaderLogo(() => {
        return `
          <div class="tangyzen-nav">
            <a href="/tangyzen" class="tangyzen-nav-link">💰 ${I18n.t('tangyzen.deals')}</a>
            <a href="/tangyzen/music" class="tangyzen-nav-link">🎵 ${I18n.t('tangyzen.music')}</a>
            <a href="/tangyzen/movies" class="tangyzen-nav-link">🍿 ${I18n.t('tangyzen.movies')}</a>
            <a href="/tangyzen/reviews" class="tangyzen-nav-link">⚖️ ${I18n.t('tangyzen.reviews')}</a>
            <a href="/tangyzen/arts" class="tangyzen-nav-link">📸 ${I18n.t('tangyzen.arts')}</a>
            <a href="/tangyzen/blogs" class="tangyzen-nav-link">✍️ ${I18n.t('tangyzen.blogs')}</a>
          </div>
        `;
      });
      
      // Register custom CSS
      api.registerStylesheet('tangyzen/theme');
      api.registerStylesheet('tangyzen/deal-card');
      
      // Add TangyZen settings to admin
      api.addAdminNavbarElement({
        name: 'tangyzen',
        label: 'tangyzen.title',
        href: '/admin/plugins/tangyzen'
      });
    });
  },
  
  getContentTypeIcon(type) {
    const icons = {
      deal: '💰',
      music: '🎵',
      movie: '🍿',
      review: '⚖️',
      art: '📸',
      blog: '✍️'
    };
    return icons[type] || '📄';
  },
  
  getContentTypeLabel(type) {
    const labels = {
      deal: 'tangyzen.deals',
      music: 'tangyzen.music',
      movie: 'tangyzen.movies',
      review: 'tangyzen.reviews',
      art: 'tangyzen.arts',
      blog: 'tangyzen.blogs'
    };
    return I18n.t(labels[type] || 'tangyzen.content');
  }
};

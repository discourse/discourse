import Ember from 'ember';
import { ajax } from 'discourse/lib/ajax';

export default Ember.Route.extend({
  // Deals page route
  renderTemplate() {
    this.render('deals-page', { into: 'application' });
  },

  // Content hub route  
  model(params) {
    const controller = this.controllerFor('tangyzen');
    const type = params.type || controller.get('currentType') || 'gaming';
    
    // Only load content type data, not deals
    const contentTypes = ['gaming', 'music', 'movies', 'reviews', 'arts', 'blogs'];
    
    if (!contentTypes.includes(type)) {
      return { type: 'not-found' };
    }
    
    return ajax(`/tangyzen/${type}.json`, {
      data: {
        page: params.page || 1,
        sort: params.sort || 'trending',
        category: params.category,
        limit: 20
      }
    }).then(response => {
      const dataKey = Object.keys(response).find(k => 
        k.includes(type) || k.includes(type + 's')
      ) || type;
      
      return {
        items: response[dataKey] || [],
        meta: response.meta || {},
        type: type
      };
    });
  },
  
  setupController(controller, model) {
    controller.setProperties({
      items: model.items,
      meta: model.meta,
      currentType: model.type,
      isLoading: false
    });
  },
  
  actions: {
    refresh() {
      this.refresh();
    },
    
    changeType(type) {
      this.transitionTo({ queryParams: { type } });
    },
    
    changeSort(sort) {
      this.transitionTo({ queryParams: { sort } });
    },
    
    loadMore() {
      const controller = this.controllerFor('tangyzen');
      const nextPage = controller.get('meta.page') + 1;
      const type = controller.get('currentType');
      
      controller.set('isLoadingMore', true);
      
      return ajax(`/tangyzen/${type}.json`, {
        data: {
          page: nextPage,
          sort: controller.get('meta.sort')
        }
      }).then(response => {
        const dataKey = Object.keys(response).find(k => 
          k.includes(type) || k.includes(type + 's')
        ) || type;
        
        const items = controller.get('items').concat(response[dataKey] || []);
        
        controller.setProperties({
          items: items,
          'meta.page': nextPage,
          isLoadingMore: false
        });
      });
    }
  }
});

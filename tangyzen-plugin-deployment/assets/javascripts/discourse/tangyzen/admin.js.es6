import { withPluginApi } from 'discourse/lib/plugin-api';
import { ajax } from 'discourse/lib/ajax';
import I18n from 'I18n';

export default {
  name: 'tangyzen-admin',
  
  initialize(container) {
    withPluginApi('0.8.31', api => {
      // Add admin menu item
      api.addAdminMenuLink({
        label: 'tangyzen.admin.title',
        route: 'adminPlugins.tangyzen',
        icon: 'chart-bar'
      });
      
      // Initialize admin routes
      initializeAdminRoutes(api);
      
      // Add admin route helpers
      api.registerValueTransformer('tangyzen-admin-routes', {
        from: 'transform',
        to: 'tangyzen-admin-routes',
        transform: (value) => value
      });
    });
  },
  
  deinitialize() {
    // Cleanup when plugin is disabled
  }
};

function initializeAdminRoutes(api) {
  // Add custom admin route
  api.addAdminSidebarSectionLink(
    'tangyzen',
    {
      label: 'tangyzen.admin.overview',
      route: 'adminPlugins.tangyzen',
      icon: 'chart-pie',
      text: I18n.t('tangyzen.admin.menu_title')
    }
  );
}

// Export admin API service
export const TangyzenAdmin = {
  
  // Get admin overview stats
  getOverview() {
    return ajax('/admin/plugins/tangyzen', {
      type: 'GET'
    });
  },
  
  // Get content list by type
  getContentList(type, params = {}) {
    return ajax(`/admin/plugins/tangyzen/content/${type}`, {
      type: 'GET',
      data: params
    });
  },
  
  // Update content
  updateContent(type, id, data) {
    return ajax(`/admin/plugins/tangyzen/content/${type}/${id}`, {
      type: 'PATCH',
      data: data
    });
  },
  
  // Delete content
  deleteContent(type, id) {
    return ajax(`/admin/plugins/tangyzen/content/${type}/${id}`, {
      type: 'DELETE'
    });
  },
  
  // Feature content
  featureContent(type, id) {
    return ajax(`/admin/plugins/tangyzen/content/${type}/${id}/feature`, {
      type: 'POST'
    });
  },
  
  // Unfeature content
  unfeatureContent(type, id) {
    return ajax(`/admin/plugins/tangyzen/content/${type}/${id}/unfeature`, {
      type: 'POST'
    });
  },
  
  // Get users list
  getUsersList(params = {}) {
    return ajax('/admin/plugins/tangyzen/users', {
      type: 'GET',
      data: params
    });
  },
  
  // Get analytics data
  getAnalytics(period = '7d') {
    return ajax('/admin/plugins/tangyzen/analytics', {
      type: 'GET',
      data: { period }
    });
  },
  
  // Sync Web3 data
  syncWeb3Data(collections = [], forceRefresh = false) {
    return ajax('/admin/plugins/tangyzen/web3/sync', {
      type: 'POST',
      data: {
        collections,
        force_refresh: forceRefresh
      }
    });
  },
  
  // Get settings
  getSettings() {
    return ajax('/admin/plugins/tangyzen/settings', {
      type: 'GET'
    });
  },
  
  // Update settings
  updateSettings(data) {
    return ajax('/admin/plugins/tangyzen/settings', {
      type: 'PUT',
      data: data
    });
  },
  
  // Check data consistency
  checkDataConsistency() {
    return ajax('/admin/plugins/tangyzen/data-consistency', {
      type: 'GET'
    });
  },
  
  // Repair data
  repairData() {
    return ajax('/admin/plugins/tangyzen/repair-data', {
      type: 'POST'
    });
  }
};

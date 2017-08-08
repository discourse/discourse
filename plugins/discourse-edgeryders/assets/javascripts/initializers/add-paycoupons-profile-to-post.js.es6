import { withPluginApi } from 'discourse/lib/plugin-api';

function addPayCouponsIcon(api) {


    api.decorateWidget('poster-name:after', helper => {
      const post = helper.getModel();
      const paycouponsUsername = post.poster_paycoupons_username;

      if (!Ember.isEmpty(paycouponsUsername)) {
        return helper.h('span.post-icon', [
          helper.h('a.paycoupons-icon', {
            href:'https://www.pay.coupons/'+paycouponsUsername,
            title: 'I offer PayCoupons',
            target:'_blank'
          }, helper.h('img', {src:'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAQCAYAAAAWGF8bAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAApwAAAKcBDzod3AAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAH4SURBVDiNndK7a5NRGMfx73nznjRNLdh0kCa2sRUtFrSig4iXojh066KuIoKDKBaLo1gLDtLJf0AnlyJ10ILERBHBycULTdpYsCpqW5OgzYW8lzwOSoj65qJnOw+/8+F5zjnwD8tK6D12XCfsuM7YMfOAV0a1AslDelxTTwqcAXy/yvOmzx5WR3Bqs0ZDaAa/FdcXHVOnBM7WYABDpaXe8ezQ5UPCiWrds0MRlJPw31BKxkXQ1Xo+iLMYwU1vxl3spbLS9bOOmupOTV/1BK3Hei+umlVK+qQYwH46jP1yK7K2EbE0iFcL6nUoNb3rN1BiwbBdMK+XlvtOracHlPM2QuVzCKS1a74T3T145cHxtJLntFtfN1wq3x6dXFreaR4eOU/ZH2wF+VstZZKmU9BPyHbuc5JbuBsO/zcGoNpDO0yURIyeHErbWA2muzmm6e6AXAmCGs7N2pSdP1MKQ0RN4XMx+r807eBazOHCPZvUqnCw3/vHGTpn3wJemds/NgX3Rw1GBw1GBgySK57PjaFO4oJM+LY1BzsD4DPg9IzNp+91QAB9zImb0dU5ZbgNwdhChblkhbW8N1YFARx/ZUJ1Feom78+7ZIpNRqgFA0fLC+W28od6wXi6QrZYvzMAXAuzdh9cfzPW8f7Ri3zbJl+9M/WXiHx79+wHd+vCoRq5wjsAAAAASUVORK5CYII='}) )
        ]);

      }

    });

}

export default {
  name: 'add-paycoupons-profile-to-post',

  initialize() {
    withPluginApi('0.1', addPayCouponsIcon);
  }
};

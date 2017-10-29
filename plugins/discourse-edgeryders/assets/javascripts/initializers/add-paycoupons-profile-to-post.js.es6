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
          }, helper.h('img', {src:'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABQAAAAQCAYAAAAWGF8bAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAApgAAAKYB3X3/OAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAAIGSURBVDiNndNPaNNQHAfwb9KXZI6utl217o+TjdKuHiZDe1AnigqtxYsHB/47CCLitRU2T7kNBt7HxIvgTZRdJk4Ui3+YQR0yGHPQUp1blXbtSJo1SZfEw6TglrTV7/HxfZ/3fg8e8A8pJ2NXpeGbxfUzdwwlEb9l1aGageSRc4NGrv2Rnu4Nw9zaQntLatvheTfFv1aaBsXEKR+94XuoLwZipsbu6GaOLj+f7Omf3lesTPI8rwAAsYJMHqScvfxFF/oOGgZdW//lpvEmRPA+yOBtiCC7xxsFED0/Rw0DGLIEy8n4dXG2/74pOR15F42JsxxmBlh89zlQYawnWegkR3aMLI/EIquF/U9SzkB3KuDGpz4HMnsd9V6kFsoEwi/D1z4r/seUfPdEh1Q4MHUpeigy2+3FbuEKaIprCtoeTSxpRF8YSKc5/653IQbMvO+/MQBgXR6WmCrLhNY24VRMqJv25bGTgJsD1lXAxQGJV4Bi0adJMPOAGEAkXUf7k3EBGE0Bi2tApMO6Q7d6pm5T/rw89LXaEDzdA1wIAse6tlBLkOJhcL3fkseXGoOiBqxIwI1nQH7DBgSAlnvTE4N0dpltMPXHn4CQA+Q6Z9e+Ade1crGzqNsWny4BBZtbWYKtYzMfPKWK7dlCDpC0+phRVf/+ei2ZuXhF9L/QSVvjq1ikmv9R+A3gU7PyzoTJ3gAAAABJRU5ErkJggg=='}) )
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

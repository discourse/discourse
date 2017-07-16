import { withPluginApi } from 'discourse/lib/plugin-api';


// API doc: https://github.com/discourse/discourse/blob/master/app/assets/javascripts/discourse/lib/plugin-api.js.es6#L11
export default {
  name: 'with-plugin-sample',
  initialize() {

     withPluginApi('0.1', api => {
       api.onPageChange((url, title) => {
               // console.log('the page changed to: ' + url + ' and title ' + title);
               // https://github.com/hasenj/bidiweb
               bidiweb.style('.regular.contents *');
             });
     });
  }
}



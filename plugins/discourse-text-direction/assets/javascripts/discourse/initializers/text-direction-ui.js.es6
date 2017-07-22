import { withPluginApi } from 'discourse/lib/plugin-api';
import { onToolbarCreate } from 'discourse/components/d-editor';

function initializePlugin(api)
{
  const siteSettings = api.container.lookup('site-settings:main');

  if (siteSettings.discourse_text_direction_enabled) {
    api.onToolbarCreate(toolbar => {
        toolbar.addButton({
          id: "text_direction_rtl_button",
          group: "extras",
          title: 'composer.text_direction_rtl_label',
          icon: "align-right",
          perform: e => e.applySurround('[text-direction=rtl]\n', '\n[/text-direction]\n', 'text_direction_rtl_default_text')
        });
      });
  }
}

export default
{
  name: 'text-direction-ui',
  initialize(container)
  {
    withPluginApi('0.1', api => initializePlugin(api), { noApi: () => priorToApi(container) });
  }
};

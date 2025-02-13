things to consider for palette:

* better relationship between settings and the config pages/areas they are in, so we can
  link to the config page setting tab. primary area first area?
* consider sub-pages of things like plugins (AI has 6) and other things like Logs & screening, do we want them?
* add reports as data source
* concept of "command" data sources, e.g. like https://dev.discourse.org/t/add-an-interface-to-search-the-admin-section-for-settings-themes-pages-and-plugins/121531/5, e.g. "Set up secure uploads"
* keep last used filters saved in localstorage
* might need to take a pass to move all of the page title and descriptions to a single place
  in client.en.yml, then use those fort the sidebar link labels too, then we have a consistent
  way of managing them

```
admin_js:
  config_pages:
    security:
      title: "Security"
      header_description: "Configure security settings, including two-factor authentication, moderator privileges, and content security policies"
    logs:
      title: "Logs & screening"
      header_description: "Logs and screening allow you to monitor and manage your community, ensuring that it remains safe and respectful. You can view logs of all actions taken by staff members, search logs, and user screening configuration"
      sub_pages:
        staff_actions:
          title: "Staff actions"
        screened_emails:
          title: "Screened emails"
        ...
```

Then give plugins a way to register these?

```
api.registerConfigPage(self.name, {
  title: "Usage",
  description: "Tokens are the basic units that LLMs use to understand and generate text, usage data may affect costs."
  route: "adminPlugins.show.discourse-ai-usage"
});
```

Or maybe new server-side?

```
add_admin_config_route("ai.config_pages.usage.title", "ai.config_pages.usage.description", "adminPlugins.show.discourse-ai-usage")
```

These would be pages beneath the admin_route layer. Maybe also could add `sub_routes:` param to `add_admin_route`?

DONE

* lightweight setting payload? name and description and keywords?
* add theme data source
* add component data source
* change the admin nav map to include the description label for the relevant config page
  so we can use that when generating the links
* little menu to toggle showing only page/setting/theme/component

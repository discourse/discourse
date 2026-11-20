# Hamilton

Hamilton adds a configurable greeting and public product documentation to Discourse.

- Visit `/hamilton` to see **Hello world** by default.
- Administrators can change the greeting at `/admin/plugins/hamilton/settings`.
- Visit `/hamilton/docs` to read this README in Discourse.
- The example endpoint at `/hamilton/examples.json` returns `{"hello":"world"}` independently of the greeting.

See the [Hamilton guide](doc/hamilton.md) for installation, authorization,
architecture, and tests.

See the [Roadmap](doc/roadmap.md) for Hamilton’s goals and planned milestones.
Modeling and simulation are planned; Hamilton has no custom product data storage yet.

See the [technical guide in the source repository](https://github.com/discourse/discourse/blob/main/plugins/hamilton/doc/technical-guide.md)
for runtime requirements and further implementation and testing details.

The plugin was scaffolded from discourse/discourse-plugin-skeleton at `9c79225314c80e3a5328730c51ff00fa5c7984c8`.

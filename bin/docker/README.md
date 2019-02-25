# Developing using Docker

Since Discourse runs in Docker, why not develop there?  If you have Docker installed, you should be able to run Discourse directly from your source directory using a Discourse development container.

You can find installation instructions and related discussion in this meta topic:
https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/102009

##### Where is the container image/Dockerfile defined?

The Dockerfile comes from [discourse/discourse_docker on GitHub](https://github.com/discourse/discourse_docker), in particular [image/discourse_dev](https://github.com/discourse/discourse_docker/tree/master/image/discourse_dev).

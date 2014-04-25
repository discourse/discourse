Deploying [Discourse on Docker][1] is currently our recommended setup. It avoids many pitfalls installations have, such as misconfigured nginx, sub-optimal Ruby defaults and so on. 

The Docker based setup ensures we are all on the same page when diagnosing installation issues and completely eradicates a class of support calls. 

Today, all sites hosted by Discourse are on Docker. 

This is a basic guide on how to move your current Discourse setup to a Docker based setup.

## Getting started

First, get a blank site with working email installed. Follow the guide at https://github.com/discourse/discourse_docker and install a new, empty Discourse instance.

**Tips:** 

- Bind the web to a different port than port 80, if you are on the same box. Eg:

        expose:
          - "81:80"

- Be sure to enter your email in the developer email section, so you get admin:

        env:
          # your email here
          DISCOURSE_DEVELOPER_EMAILS: 'my_email@email.com'


- Make sure email is setup and working by visiting `/admin/email` and sending a test email.

- Make sure you have ssh access to your container `./launcher ssh my_container` must work. 

**If any of the above is skipped your migration will fail.**

At the end of this process you will have a working website. Carry on.


## Exporting and importing the old site

- Ensure you are running the absolute latest version of Discourse. We had bugs in the export code in the past, make sure you are on latest before attempting an export.

- On your current instance
  - go to `/admin/backups` and click on the ![Backup](https://meta-discourse.r.worldssl.net/uploads/default/3418/083f92873b96625c.png) button.
  - once the backup is done, you will be able to ![Download](https://meta-discourse.r.worldssl.net/uploads/default/3420/fd77ea7e700101cd.png) it.

- On your newly installed docker instance
  - enable the `allow_restore` site setting
  - refresh your browser for the change to be taken into account
  - go to `/admin/backups` and ![Upload](https://meta-discourse.r.worldssl.net/uploads/default/3419/21e172a1f1059364.png) your backup.
  - once your upload is done, click on the ![Restore](https://meta-discourse.r.worldssl.net/uploads/default/3421/2946f976f3bea2bb.png) button


- Destroy old container `./launcher destroy web` 

- Change port binding so its on 80

- Start a new container

Yay. You are done. 

  [1]: INSTALL-digital-ocean.md

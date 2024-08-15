---
title: Get started with Theme Creator and the Theme CLI
short_title: Theme Creator
id: theme-creator

---
This topic will walk you through how to use the [Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950) with our [Theme Creator](https://meta.discourse.org/t/theme-creator-create-and-show-themes-without-installing-discourse/84942) site to develop a theme and preview your changes on a live Discourse site. 

1. [Sign up for an account here on Meta](https://meta.discourse.org/signup) if you haven't already

2. [Log in to Theme Creator](https://discourse.theme-creator.io/login) 

3. Install the Theme CLI via the [instructions here](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950)

4. Create a new theme on Theme Creator by:
    * visiting  [https://discourse.theme-creator.io/my/themes](https://discourse.theme-creator.io/my/themes) 

   * Clicking <kbd> Install</kbd>, and selecting the "Create New" option. 
   * Giving your theme a unique name (you can ignore the color scheme for now). 

5. Click <kbd>advanced</kbd>, then <kbd>edit locally</kbd>, and <kbd>retrieve API key</kbd>. 

    Copy the API key that is generated.
  
  
![image|379x500, 50%](/assets/theme-creator-1.png) ![image|591x500, 50%](/assets/theme-creator-2.png)

6. Go back to your command line and type `discourse_theme download example-folder`, where example-folder is where your theme will be stored locally. Follow the prompts. 

    - Enter `https://discourse.theme-creator.io` as the **root URL** of your Discourse site. 

    - Enter your **API key** from the previous step when prompted. 
    
    - Continue following the prompts and select the theme you created in step 4. 

    - Enter yes when asked if you'd like to start watching your theme.
 
      ![06%20PM|558x227](upload://54ejg1tZAhiaNQlc7cbZl6wySoG.png) 

7. Now your local theme folder is being watched for changes, which will be automatically uploaded to Theme Creator. You can open a preview of your theme by clicking <kbd>preview</kbd> in your theme's settings on Theme Creator.  

    ![27%20PM|591x500, 67%](/assets/theme-creator-3.png) 

8. To stop watching for changes, hit <kbd>ctrl</kbd> + <kbd>c</kbd> in your command line window. To start watching for changes again type `discourse_theme watch example-theme`.

:tada: You now have a local theme directory you can edit and see your changes live! 

For an in-depth look at how themes are structured and what you can do, check out our https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648/1

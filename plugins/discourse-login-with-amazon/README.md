# Login with Amazon Plugin

A plugin that enables authentication via Login with Amazon.

For more information, please see: https://meta.discourse.org/t/login-with-amazon-plugin/117564

#### Setting up Login With Amazon to auth using localhost for development
1. create an account at developer.amazon.com
2. use the Client Id and Client Secret provided on developer.amazon.com to update your `SiteSettings.login_with_amazon_client_id` and `SiteSettings.login_with_amazon_client_secret` on your local discourse instance
3. on developer.amazon.com, Under "Web Settings", set the following settings:
   - Allowed Origins: http://localhost:4200
   - Allowed Return URLs: http://localhost:4200/auth/amazon/callback
4. create and login to an account on amazon.com with the same email you are using locally for your dev instance.
5. optionally set the following site settings on your local discourse instance:
   - `enable_local_logins: false`
   - `login_required: false`
6. start your local rails server as following:
   - ```% REDIRECT_URL_ORIGIN=http://localhost:4200 rails s```
7. at this point, when you go to localhost:4200, you should be redirected to /login and be presented with a "Login With Amazon" button. Clicking on it should 
take you to an authentication flow on amazon.com and redirect you in the end, to a logged in session at localhost: 4200.




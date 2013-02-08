<a href="http://www.discourse.org/">![Logo](https://raw.github.com/discourse/discourse/master/images/discourse.png)</a>
# Instructions for Deploying to Heroku
Below are instructions for deploying to Heroku.  I am sure they are not the long-term solution, but perhaps they will be helpful in the meantime.

## Uninteresting Set-up


    $ git clone git://github.com/discourse/discourse.git disc-fresh
    $ cd disc-fresh
    $ git init
    $ heroku create my-discourse


## Adding RedisToGo

    $ heroku addons:add redistogo:nano

    $ heroku config
    === my-discourse Config Vars
    REDISTOGO_URL: redis://redistogo:0dd02cef32ebadd4a65de872d3643b0b@dory.redistogo.com:9823/

Parse the above url into the following values that will be used later:

host: dory.redistogo.com    
port: 9823    
password: 0dd02cef32ebadd4a65de872d3643b0b    

## Editing the Discourse source

Now we need to update the redis.yml with the values we parsed from our REDISTOGO_URL.

Line 1 on redis.yml  
Old:  
`  defaults: &defaults  
    host: localhost  
    port: 6379  
    db: 0  
    cache_db: 2  
`    

New:  
`defaults: &defaults    
 	  host: "dory.redistogo.com"  
    password: "0dd02cef32ebadd4a65de872d3643b0b"  
    port: 9823  
`
(I have removed db and cache_db.)


Next, we have to update Discourse's calls to the Redis api:

Line 86 on application.rb    
Old:   

`redis_store = ActiveSupport::Cache::RedisStore.new "redis://#{redis_config['host']}:#{redis_config['port']}/#{redis_config['cache_db']}"`  

New:    

`redis_store = ActiveSupport::Cache::RedisStore.new "redis://redistogo:#{redis_config['password']}@#{redis_config['host']}:#{redis_config['port']}"`  

And  

Line 8 on discourse_redis.rb    
Old:    

`redis_opts = {:host => @config['host'], :port => @config['port'], :db => @config['db']}`

New:  

`redis_opts = {:host => @config['host'], :port => @config['port'], :password => @config['password']}'  

and Line 40  
Old:  

`"redis://#{@config['host']}:#{@config['port']}/#{@config['db']}"`  

New:
  
`"redis://redistogo:#{@config['password']}@#{@config['host']}:#{@config['port']}"`

Finally, we need to change one line where Discourse manages ActiveRecord connections to our PostgreSQL database.

Line 58 connection_management.rb:  
Old:  

`ActiveRecord::Base.connection_pool.spec.config[:host_names].first`

New:  

`ActiveRecord::Base.connection_pool.spec.config[:host]`

The changes to the Discourse source are complete.  Now we just need to do the routine tasks related to pushing to Heroku.  

## Semi-interesting Push to Heroku

This part assumes that you have already installed vagrant and the discourse-pre VM box.  If you are not going this route, I have heard there are other ways to precompile your assets on Heroku.

Precompiling Assets:

`$ vagrant up
[vagrant]$ vagrant ssh
[vagrant]$ bundle install
[vagrant]$ rake assets:precompile`

Now that we've precompiled assets, we stage our files, commit, and push.

`$ git add -A
$ git commit -m "Modifies Discourse for Heroku and Precompiles Assets"
$ git push heroku master`

Finally, run your rake tasks.

`$ heroku run rake db:migrate
$ heroku run rake db:seed_fu`

Enjoy your new instance of Discourse on Heroku!

## Add an e-mail client  
Try [Sendgrid](https://devcenter.heroku.com/articles/sendgrid#sendgrid-free).
I am currently working on this and will notify later.











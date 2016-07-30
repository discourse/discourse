require 'fileutils'
require File.expand_path(File.dirname(__FILE__) + "/mbox.rb")

=begin

PREREQUISITES and INFORMATION:

COOKIES
in order to be able to extract users' email addresses correctly from the Google Group, you will need
to have access to a Manager account of the Google Group. Having logged into Google Groups with this Manager account,
export the cookies.txt from your browser (I used this Chrome extension to get the cookies.txt file:
https://chrome.google.com/webstore/detail/cookiestxt/njabckikapfpffapmjgojcnbfjonfjfg)
(Without this step, the email addresses cannot be harvested from the Google Group, and this will mess up creation
of new users on Discourse)

Once you have the cookies.txt file, the easiest way to get it into your Docker container is to upload it as an attachment
to a post in your discourse forum. You can get the URL from the post, and you need to prepend '/var/www/discourse/public' to the URL,
which will be something like '/uploads/default/original/1X/245aa0cdc6847cf59647e1c7102e253e99d40b69.txt'



INSTRUCTIONS:
**run this script from INSIDE your Discourse Docker container**
$ ssh <your-discourse-server>
$ cd /var/discourse
$ ./launcher enter app
# apt install sqlite3 libsqlite3-dev
# gem install sqlite3
# cd /var/www/discourse/script/import_scripts
# ruby googlegroups.rb <name-of-your-google-group-goes-here>

=end

class ImportScripts::GoogleGroups < ImportScripts::Mbox

  def initialize(google_group_name)
    @google_group_name = google_group_name
    super("/tmp/google-group-crawler/#{@google_group_name}")
    setup_google_group
  end

  def execute
    scrape_google_group_to_mbox
    import_mbox_to_discourse
    super
  end

  # a valid cookie file called cookies.txt from google groups is expected in the /tmp folder
  def setup_google_group
    ENV['_GROUP'] = @google_group_name
    ENV['_WGET_OPTIONS'] = "--load-cookies /tmp/cookies.txt --keep-session-cookies"
    puts "######## Your Google Group name is #{@google_group_name}"
    puts "######## SoI'm expecting the Google Group URL to be https://groups.google.com/forum/#!forum/#{@google_group_name}"
  end

  # scrape content of the Google Group using https://github.com/icy/google-group-crawler
  # do everything in /tmp/
  def scrape_google_group_to_mbox
    FileUtils.rm_rf("/tmp/google-group-crawler") # idempotent
    system 'echo "######## Clone the Google Group Crawler from icy"'
    system 'git clone https://github.com/icy/google-group-crawler /tmp/google-group-crawler'
    # perform the scrape
    Dir.chdir '/tmp/google-group-crawler/' do
      system 'chmod +x ./crawler.sh'
      system 'echo "######## Start the first pass collection of topics"'
      system './crawler.sh -sh > wget.sh'
      system 'chmod +x ./wget.sh'
      system 'echo "######## Iterate through topics to get messages"'
      system './wget.sh'
      system "chmod -R 777 #{@google_group_name}"
      #system('chmod 777 member.csv'
    end
  end

  # import mbox data to Discourse using /script/import_scripts/mbox.rb which is part of Discourse
  def import_mbox_to_discourse
    # rename folder 'mbox' in the scrape data to 'messages' so that the superclass mbox.rb will work
    # this step might be able to be removed with some refactoring of mbox.rb?
    Dir.chdir "/tmp/google-group-crawler/#{@google_group_name}" do
      FileUtils.mv('mbox','messages')
    end
    # system 'su discourse'
    # system 'RAILS_ENV=development ruby ./mbox.rb'
    # import is now enacted by invocation of ImportScripts::Mbox#execute
  end
end

ImportScripts::GoogleGroups.new(ARGV[0]).perform

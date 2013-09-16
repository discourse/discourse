source /var/.cloud66_env
cd $RAILS_STACK_PATH
echo "" >> config/thin.yml
echo "chdir: <%= ENV['RAILS_STACK_PATH'] %>" >> config/thin.yml
echo "environment: <%= ENV['RAILS_ENV'] %>" >> config/thin.yml
echo "log: <%= ENV['RAILS_STACK_PATH/log/thin.log'] %>" >> config/thin.yml
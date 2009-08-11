# Deployment recipe for radiant cms
# production is running on mod_rails
# and staging nginx + mongrel clustre

# Juicer minifier need some gems
# Juicer for minifying css and javascript
# GO: http://github.com/cjohansen/juicer/tree/master

require 'rubygems'
require 'juicer'

# Common options
set :application, "application-name"
set :repository,  "/Users/developer/application-name"
set :scm,         :git

set(:env, 'test') unless exists?(:env)

if env == 'production'
  puts "********* DEPLOYING TO PRODUTION *********"
  set   :branch,      "production"
  role  :web,         "app.fi"
  role  :app,         "app.fi"
  role  :db,          "app.fi", :primary => true
  set   :base_folder, "/var/homes/app/www"
  set   :user,        "app"
  set   :deploy_to,   "#{base_folder}/#{application}"
  set   :runner,      "app"
  set   :use_sudo,    false
  set   :spinner,     false
  set   :reaper,      false
  set   :asset_folder,"#{base_folder}/static/assets"
  set   :deploy_via,  :copy
  set   :compression, :zip
  set   :asset_host,  "assets.app.fi"
  set   :web_host,    "www.app.fi"
  set   :rails_env,   "production"
  
  namespace :deploy do
    desc "Restart Application"
    task :restart, :roles => :app do
      run "touch #{current_path}/tmp/restart.txt"
    end
      
    desc "Stop Application - not in use"
    task :stop, :roles => :app do
      
    end
    
    desc "Start Application"
    task :start, :roles => :app do
      run "touch #{current_path}/tmp/restart.txt"
    end    
      
  end
    
  
elsif env == 'staging'
  puts "********* DEPLOYING TO STAGING *********"
  set   :branch,      "staging"
  role  :web,         "staging.app.fi"
  role  :app,         "staging.app.fi"
  role  :db,          "staging.app.fi", :primary => true
  set   :user,        "developer"
  set   :spinner,     false
  set   :reaper,      false
  set   :use_sudo,    false
  set   :deploy_via,  :copy
  set   :compression, :gz  
  set   :runner,      "developer"  
  set   :base_folder, "/home/developer/www"
  set   :asset_folder, "#{base_folder}/static/assets"
  set   :deploy_to,   "#{base_folder}/#{application}"  
  set   :asset_host,  "assets.dev.app.fi"
  set   :web_host,    "dev.app.fi"
  set   :rails_env,   "staging"
  
  
  namespace :deploy do    
    %w(start stop restart).each do |action|
      desc "#{action} the Thin processes"
      task action.to_sym do
        find_and_execute_task("thin:#{action}")
      end
    end    
  end
  
  namespace :thin do
    %w(start stop restart).each do |action|
      desc "#{action} the app's Thin Cluster"
      task action.to_sym, :roles => :app do
        run "/etc/init.d/thin restart"
      end
    end
  end
   
  end
  
  
else
  puts "********* DEPLOYING TO TEST *********"
  set   :application, "pshp-rekry-erva"
  set   :base_folder, "/Users/japesuut/Development/Gits/"
  set   :deploy_to,   "#{base_folder}/#{application}"
  set   :asset_host,  "localhost:3000"
end

namespace :deploy do
  desc "Minify javascript files"
  task :minify_js, :roles => :app do
    run "find #{current_path}/public/javascripts/ -name *.js -type f -maxdepth 1 -exec juicer merge -i {} --force ';'; true"
    run "rename -fv 's/\.min.js$/\.js/' #{current_path}/public/javascripts/*.js"
  end
  
  desc "Minify stylesheet files"
  task :minify_css, :roles => :app do
    #run "find #{current_path}/public/stylesheets/ -name *.min.css -type f -exec rm {} ';'; true"
    run "find #{current_path}/public/stylesheets/ -name *.css -type f -maxdepth 1 -exec juicer merge -h http://#{asset_host} {} --force ';'; true"
    run "rename -fv 's/\.min.css$/\.css/' #{current_path}/public/stylesheets/*.css"
  end
  
  desc "Remove unused files from server"
  task :remove_unused_tasks, :roles => :app do
    run " mv #{current_path}/lib/tasks/backup.rake #{current_path}/lib/tasks/backup.saveme"
    run "find #{current_path}/lib/tasks/ -type f -maxdepth 1 -name *.rake -exec rm {} ';'; true"
    run " mv #{current_path}/lib/tasks/backup.saveme #{current_path}/lib/tasks/backup.rake"
    run "rm -rf #{current_path}/features"
  end
    
  desc "Migrate extension for Radiant"
  task :radiant_migrations, :roles => :app do
    run "cd #{current_path}; rake db:migrate:extensions RAILS_ENV=#{env} --trace"
  end
  
  
  task :move_images_to_public, :roles => :app do
    run "mv #{previous_release}/public/uploads #{current_path}/public"
  end
  
  desc "Copy assets to asset servers home folder"
  task :link_assets, :roles => :app do
    run "[-d '#{asset_folder}' ] || rm -rfv #{asset_folder}"
    run "find #{current_path}/public -type f -maxdepth 1 -exec rm {} ';'; true"
    run "cp #{current_path}/production_public/* #{current_path}/public/"
    run "ln -s #{current_path}/public #{asset_folder}"
    run "touch #{asset_folder}/.htaccess"
    htaccess = 'RewriteEngine On \n RewriteCond %{HTTP_REFERER} !^$  \n RewriteCond %{HTTP_REFERER} !^http://(www\.)?app\.fi.*$ [NC]  \n RewriteCond %{HTTP_REFERER} !^http://app\.fi.*$ [NC]  \n RewriteCond %{HTTP_REFERER} !^http://(assets\.)app\.fi.*$ [NC]  \n RewriteRule \.(gif|GIF|jpg|JPG|png|bmp|css)$ - [R,L]  \n <FilesMatch "\.(ico|pdf|flv|jpe?g|png|gif|js|css|swf)$">  \n ExpiresActive On  \n ExpiresDefault "access plus 1 year"  \n </FilesMatch>'

    run "echo '#{htaccess.strip}' > #{asset_folder}/.htaccess"
  end  
  
  after "deploy:migrate", "deploy:radiant_migrations"
  after "deploy:symlink", "deploy:remove_unused_tasks", "deploy:minify_css", "deploy:link_assets", "deploy:move_images_to_public", "deploy:minify_js"
  
end



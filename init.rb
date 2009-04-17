my_dir = File.expand_path(File.dirname(__FILE__))+'/lib'
ActiveSupport::Dependencies.load_once_paths.delete my_dir unless RAILS_ENV == 'production'

$: << my_dir
require 'golem'
